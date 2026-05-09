require "test_helper"

class GeneratePeriodizationJobTest < ActiveJob::TestCase
  setup do
    @organization = organizations(:steimfit)
    @organization.update!(equipment_list_md: "- Barra olímpica\n- Anilhas\n")

    @student = students(:alice)
    @student.update!(
      age: 32,
      sex: "Feminino",
      primary_goal: "Hipertrofia",
      weekly_frequency: 3,
      restrictions_summary: "Lombar sensível",
      anamnesis_md: "## Histórico\n\nLevantamento básico há 2 anos."
    )
    @trainer = users(:one)

    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @trainer,
      kind: "periodization_create",
      transcript: "Foco em hipertrofia, três treinos divididos por padrão de movimento."
    )

    @version = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)
  end

  test "applies a schema-valid plan, marks the version completed, and forwards student/equipment context" do
    valid_plan = {
      "body_md" => "## Mesociclo\n\nFoco em hipertrofia, 3 sessões/semana.",
      "workouts" => [
        { "name" => "A", "content_md" => "- Agachamento 4x8", "position" => 1 },
        { "name" => "B", "content_md" => "- Supino 4x8",      "position" => 2 },
        { "name" => "C", "content_md" => "- Levantamento terra 4x6", "position" => 3 }
      ]
    }

    captured_user_prompt = nil
    captured_schema = nil
    fake_chat = build_fake_chat(content: valid_plan, capture_prompt: ->(p) { captured_user_prompt = p }, capture_schema: ->(s) { captured_schema = s })

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version.id)
    end

    @version.reload
    assert_equal "completed", @version.status
    assert_match(/Mesociclo/, @version.body_md)
    assert_equal 3, @version.workouts.count
    assert_equal %w[A B C], @version.workouts.order(:position).pluck(:name)

    assert_match(/Hipertrofia/, captured_user_prompt)
    assert_match(/Barra olímpica/, captured_user_prompt)
    assert_match(/três treinos/, captured_user_prompt)
    assert_equal GeneratePeriodizationJob::SCHEMA, captured_schema
  end

  test "marks the version failed when the LLM response is missing required keys" do
    invalid_plan = { "body_md" => "ok" } # workouts missing

    fake_chat = build_fake_chat(content: invalid_plan)

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version.id)
    end

    @version.reload
    assert_equal "failed", @version.status
    assert_match(/workouts/, @version.error_message)
    assert_equal 0, @version.workouts.count
  end

  test "marks the version failed when RubyLLM raises" do
    fake_chat = Object.new
    fake_chat.define_singleton_method(:with_instructions) { |_| self }
    fake_chat.define_singleton_method(:with_schema) { |_| self }
    fake_chat.define_singleton_method(:ask) { |_| raise RuntimeError, "Anthropic indisponível" }

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version.id)
    end

    @version.reload
    assert_equal "failed", @version.status
    assert_equal "Anthropic indisponível", @version.error_message
  end

  test "is a no-op on a non-generating version" do
    @version.update!(error_message: "boom")
    @version.transition_to!(:failed)

    called = false
    RubyLLM.stub :chat, ->(*) { called = true; Object.new } do
      GeneratePeriodizationJob.perform_now(@version.id)
    end

    assert_not called
    assert_equal "failed", @version.reload.status
  end

  # --- :workout scope ---

  class WorkoutScopeTest < ActiveJob::TestCase
    setup do
      @organization = organizations(:steimfit)
      @organization.update!(equipment_list_md: "- Barra olímpica\n- Anilhas\n")

      @student = students(:alice)
      @student.update!(
        age: 32, sex: "Feminino", primary_goal: "Hipertrofia",
        weekly_frequency: 3, restrictions_summary: "Lombar sensível",
        anamnesis_md: "## Histórico\n\nLevantamento básico há 2 anos."
      )
      @trainer = users(:one)

      create_recording = VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_create",
        transcript: "Plano inicial."
      )
      @parent_version = @student.start_periodization!(trainer: @trainer, voice_recording: create_recording)
      @parent_version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano\n\nMesociclo base.",
          workouts: [
            { name: "A", content_md: "Agachamento 4x8", position: 1 },
            { name: "B", content_md: "Supino 4x8", position: 2 },
            { name: "C", content_md: "Levantamento terra 3x5", position: 3 }
          ]
        },
        trainer: @trainer,
        voice_recording: create_recording
      )
      @parent_version.transition_to!(:completed)
      @parent_version.periodization.set_current_version!(@parent_version)

      @target_workout = @parent_version.workouts.find_by(position: 2)

      @edit_recording = VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_edit_workout",
        target_workout: @target_workout,
        transcript: "Mudar o supino reto por supino inclinado, 4x10."
      )

      @edit_version = @parent_version.periodization.start_edit!(
        scope: :workout,
        trainer: @trainer,
        voice_recording: @edit_recording,
        target_workout: @target_workout
      )
    end

    test "applies a schema-valid workout patch, replaces only the targeted workout, and copies body_md from the parent" do
      valid_patch = {
        "workout" => { "name" => "B'", "content_md" => "- Supino inclinado 4x10" }
      }

      captured_user_prompt = nil
      captured_schema = nil
      fake_chat = build_fake_chat(
        content: valid_patch,
        capture_prompt: ->(p) { captured_user_prompt = p },
        capture_schema: ->(s) { captured_schema = s }
      )

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version.id)
      end

      @edit_version.reload
      assert_equal "completed", @edit_version.status
      assert_equal @parent_version.body_md, @edit_version.body_md, "body_md must be copied unchanged from parent"

      by_position = @edit_version.workouts.order(:position).index_by(&:position)
      assert_equal 3, by_position.size
      assert_equal "A", by_position[1].name
      assert_equal "Agachamento 4x8", by_position[1].content_md
      assert_equal "B'", by_position[2].name
      assert_equal "- Supino inclinado 4x10", by_position[2].content_md
      assert_equal "C", by_position[3].name
      assert_equal "Levantamento terra 3x5", by_position[3].content_md

      assert_equal GeneratePeriodizationJob::WORKOUT_SCHEMA, captured_schema
      assert_match(/Supino 4x8/, captured_user_prompt, "prompt must include the parent workouts as context")
      assert_match(/posição 2/, captured_user_prompt, "prompt must reference the target workout's position")
      assert_match(/inclinado/, captured_user_prompt, "prompt must include the trainer transcript")
    end

    test "marks the edit version failed when the LLM response is missing the workout key" do
      invalid_patch = { "body_md" => "wrong shape" }
      fake_chat = build_fake_chat(content: invalid_patch)

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version.id)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_match(/workout/, @edit_version.error_message)
      assert_equal 0, @edit_version.workouts.count, "no workouts should be persisted on a failed edit"
    end

    test "marks the edit version failed when RubyLLM raises" do
      fake_chat = Object.new
      fake_chat.define_singleton_method(:with_instructions) { |_| self }
      fake_chat.define_singleton_method(:with_schema) { |_| self }
      fake_chat.define_singleton_method(:ask) { |_| raise RuntimeError, "Anthropic indisponível" }

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version.id)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_equal "Anthropic indisponível", @edit_version.error_message
    end

    private
      def build_fake_chat(content:, capture_prompt: nil, capture_schema: nil)
        response = Struct.new(:content).new(content)
        chat = Object.new
        chat.define_singleton_method(:with_instructions) { |_| self }
        chat.define_singleton_method(:with_schema) do |s|
          capture_schema.call(s) if capture_schema
          self
        end
        chat.define_singleton_method(:ask) do |prompt|
          capture_prompt.call(prompt) if capture_prompt
          response
        end
        chat
      end
  end

  private
    def build_fake_chat(content:, capture_prompt: nil, capture_schema: nil)
      response = Struct.new(:content).new(content)
      chat = Object.new
      chat.define_singleton_method(:with_instructions) { |_| self }
      chat.define_singleton_method(:with_schema) do |s|
        capture_schema.call(s) if capture_schema
        self
      end
      chat.define_singleton_method(:ask) do |prompt|
        capture_prompt.call(prompt) if capture_prompt
        response
      end
      chat
    end
end
