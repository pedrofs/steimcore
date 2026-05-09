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
