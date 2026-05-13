require "test_helper"

class GeneratePeriodizationJobTest < ActiveJob::TestCase
  setup do
    @organization = organizations(:steimfit)
    @organization.update!(equipment_list_md: "- Barra olímpica\n- Anilhas\n")

    @student = students(:alice)
    @student.update!(
      birthday: Date.new(1994, 1, 1),
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
    walk_recording_to_generating!(@recording)

    @version = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)
  end

  test "applies a schema-valid plan, marks the version completed, and forwards student/equipment context" do
    valid_plan = {
      "body_md" => "## Mesociclo\n\nFoco em hipertrofia, 3 sessões/semana.",
      "workouts" => [
        {
          "name" => "A",
          "position" => 1,
          "blocks" => [ exercise_block("Agachamento", "4x8") ]
        },
        {
          "name" => "B",
          "position" => 2,
          "blocks" => [ exercise_block("Supino", "4x8") ]
        },
        {
          "name" => "C",
          "position" => 3,
          "blocks" => [
            { "kind" => "freeform", "text_md" => "Aquecimento livre" },
            exercise_block("Levantamento terra", "4x6")
          ]
        }
      ]
    }

    captured_user_prompt = nil
    captured_schema = nil
    fake_chat = build_fake_chat(content: valid_plan, capture_prompt: ->(p) { captured_user_prompt = p }, capture_schema: ->(s) { captured_schema = s })

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    @version.reload
    assert_equal "completed", @version.status
    assert_match(/Mesociclo/, @version.body_md)
    assert_equal 3, @version.workouts.count
    assert_equal %w[A B C], @version.workouts.order(:position).pluck(:name)
    assert_equal "Agachamento", @version.workouts.find_by(position: 1).blocks.first["name"]
    assert_equal "freeform", @version.workouts.find_by(position: 3).blocks.first["kind"]

    assert_match(/Hipertrofia/, captured_user_prompt)
    assert_match(/Barra olímpica/, captured_user_prompt)
    assert_match(/três treinos/, captured_user_prompt)
    assert_equal PeriodizationVersion::Generatable::SCHEMA, captured_schema
  end

  test "marks the version failed when the LLM response is missing required keys" do
    invalid_plan = { "body_md" => "ok" } # workouts missing

    fake_chat = build_fake_chat(content: invalid_plan)

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    @version.reload
    assert_equal "failed", @version.status
    assert_match(/workouts/, @version.error_message)
    assert_equal 0, @version.workouts.count
  end

  test "marks the version failed when a workout has a malformed block" do
    bad_plan = {
      "body_md" => "## ok",
      "workouts" => [
        {
          "name" => "A",
          "position" => 1,
          "blocks" => [ { "kind" => "exercise", "name" => "Supino" } ] # missing prescription
        }
      ]
    }
    fake_chat = build_fake_chat(content: bad_plan)

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    @version.reload
    assert_equal "failed", @version.status
    assert_match(/prescription/, @version.error_message)
    assert_equal 0, @version.workouts.count
  end

  test "marks the version failed when the LLM returns non-JSON content" do
    fake_chat = build_fake_chat(content: "not json")

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    @version.reload
    assert_equal "failed", @version.status
    assert_match(/JSON/, @version.error_message)
  end

  test "marks the version failed when RubyLLM raises" do
    fake_chat = Object.new
    fake_chat.define_singleton_method(:with_instructions) { |_| self }
    fake_chat.define_singleton_method(:with_schema) { |_| self }
    fake_chat.define_singleton_method(:ask) { |_| raise RuntimeError, "Anthropic indisponível" }

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    @version.reload
    assert_equal "failed", @version.status
    assert_equal "Anthropic indisponível", @version.error_message
  end

  test "is a no-op when the owning voice_recording is :cancelled (no LLM call, no version mutation)" do
    @recording.cancel!
    original_body_md = @version.body_md
    original_workout_count = @version.workouts.count

    called = false
    RubyLLM.stub :chat, ->(*) { called = true; Object.new } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    assert_not called, "LLM must not be called when recording is :cancelled"
    @version.reload
    assert_equal "generating", @version.status, "version status stays unchanged"
    assert_equal original_body_md, @version.body_md
    assert_equal original_workout_count, @version.workouts.count
  end

  test "is a no-op on a non-generating version" do
    @version.update!(error_message: "boom")
    @version.transition_to!(:failed)

    called = false
    RubyLLM.stub :chat, ->(*) { called = true; Object.new } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    assert_not called
    assert_equal "failed", @version.reload.status
  end

  test "successful generation bubbles :completed up to the owning voice recording" do
    valid_plan = {
      "body_md" => "## Mesociclo",
      "workouts" => [ { "name" => "A", "position" => 1, "blocks" => [ exercise_block("Agachamento", "4x8") ] } ]
    }
    fake_chat = build_fake_chat(content: valid_plan)

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    assert_equal "completed", @version.reload.status
    assert_equal "completed", @recording.reload.status, "version completion must bubble up to the voice recording"
  end

  test "failed generation bubbles :failed and the error message up to the owning voice recording" do
    fake_chat = build_fake_chat(content: { "body_md" => "ok" }) # workouts missing

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      GeneratePeriodizationJob.perform_now(@version)
    end

    assert_equal "failed", @version.reload.status
    @recording.reload
    assert_equal "failed", @recording.status, "version failure must bubble up to the voice recording"
    assert_equal @version.error_message, @recording.error_message
  end

  # --- :workout scope ---

  class WorkoutScopeTest < ActiveJob::TestCase
    setup do
      @organization = organizations(:steimfit)
      @organization.update!(equipment_list_md: "- Barra olímpica\n- Anilhas\n")

      @student = students(:alice)
      @student.update!(
        birthday: Date.new(1994, 1, 1), sex: "Feminino", primary_goal: "Hipertrofia",
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
            { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
            { name: "B", blocks: [ exercise_block("Supino reto", "4x8") ], position: 2 },
            { name: "C", blocks: [ exercise_block("Levantamento terra", "3x5") ], position: 3 }
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
      walk_recording_to_generating!(@edit_recording)

      @edit_version = @parent_version.periodization.start_edit!(
        scope: :workout,
        trainer: @trainer,
        voice_recording: @edit_recording,
        target_workout: @target_workout
      )
    end

    test "applies a schema-valid workout patch, replaces only the targeted workout, and copies body_md from the parent" do
      valid_patch = {
        "workout" => {
          "name" => "B'",
          "blocks" => [ exercise_block("Supino inclinado", "4x10") ]
        }
      }

      captured_user_prompt = nil
      captured_schema = nil
      fake_chat = build_fake_chat(
        content: valid_patch,
        capture_prompt: ->(p) { captured_user_prompt = p },
        capture_schema: ->(s) { captured_schema = s }
      )

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "completed", @edit_version.status
      assert_equal @parent_version.body_md, @edit_version.body_md, "body_md must be copied unchanged from parent"

      by_position = @edit_version.workouts.order(:position).index_by(&:position)
      assert_equal 3, by_position.size
      assert_equal "A", by_position[1].name
      assert_equal "Agachamento", by_position[1].blocks.first["name"]
      assert_equal "B'", by_position[2].name
      assert_equal "Supino inclinado", by_position[2].blocks.first["name"]
      assert_equal "C", by_position[3].name
      assert_equal "Levantamento terra", by_position[3].blocks.first["name"]

      assert_equal PeriodizationVersion::Generatable::WORKOUT_SCHEMA, captured_schema
      assert_match(/Supino reto/, captured_user_prompt, "prompt must include the parent workouts as context")
      assert_match(/posição 2/, captured_user_prompt, "prompt must reference the target workout's position")
      assert_match(/inclinado/, captured_user_prompt, "prompt must include the trainer transcript")
    end

    test "marks the edit version failed when the LLM response is missing the workout key" do
      invalid_patch = { "body_md" => "wrong shape" }
      fake_chat = build_fake_chat(content: invalid_patch)

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_match(/workout/, @edit_version.error_message)
      assert_equal 0, @edit_version.workouts.count, "no workouts should be persisted on a failed edit"
    end

    test "marks the edit version failed when the LLM returns a malformed block" do
      bad_patch = {
        "workout" => {
          "name" => "B'",
          "blocks" => [ { "kind" => "group" } ] # missing items
        }
      }
      fake_chat = build_fake_chat(content: bad_patch)

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_match(/items/, @edit_version.error_message)
      assert_equal 0, @edit_version.workouts.count
    end

    test "marks the edit version failed when RubyLLM raises" do
      fake_chat = Object.new
      fake_chat.define_singleton_method(:with_instructions) { |_| self }
      fake_chat.define_singleton_method(:with_schema) { |_| self }
      fake_chat.define_singleton_method(:ask) { |_| raise RuntimeError, "Anthropic indisponível" }

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_equal "Anthropic indisponível", @edit_version.error_message
    end

    private
      def exercise_block(name, prescription)
        { "kind" => "exercise", "name" => name, "prescription" => prescription }
      end

      def walk_recording_to_generating!(recording)
        recording.transition_to!(:transcribing)
        recording.transition_to!(:transcribed)
        recording.transition_to!(:generating)
      end

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

  # --- :periodization scope ---

  class PeriodizationScopeTest < ActiveJob::TestCase
    setup do
      @organization = organizations(:steimfit)
      @organization.update!(equipment_list_md: "- Barra olímpica\n- Anilhas\n")

      @student = students(:alice)
      @student.update!(
        birthday: Date.new(1994, 1, 1), sex: "Feminino", primary_goal: "Hipertrofia",
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
            { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
            { name: "B", blocks: [ exercise_block("Supino", "4x8") ], position: 2 },
            { name: "C", blocks: [ exercise_block("Levantamento terra", "3x5") ], position: 3 }
          ]
        },
        trainer: @trainer,
        voice_recording: create_recording
      )
      @parent_version.transition_to!(:completed)
      @parent_version.periodization.set_current_version!(@parent_version)

      @edit_recording = VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_edit_periodization",
        transcript: "Reescrever para foco em força, dois treinos por semana."
      )
      walk_recording_to_generating!(@edit_recording)

      @edit_version = @parent_version.periodization.start_edit!(
        scope: :periodization,
        trainer: @trainer,
        voice_recording: @edit_recording
      )
    end

    test "applies a schema-valid full plan, replaces body+workouts entirely, marks completed, and includes parent context in the prompt" do
      valid_plan = {
        "body_md" => "## Novo plano\n\nFoco em força.",
        "workouts" => [
          { "name" => "Push", "position" => 1, "blocks" => [ exercise_block("Supino", "5x5") ] },
          { "name" => "Pull", "position" => 2, "blocks" => [ exercise_block("Remada", "5x5") ] }
        ]
      }

      captured_user_prompt = nil
      captured_schema = nil
      fake_chat = build_fake_chat(
        content: valid_plan,
        capture_prompt: ->(p) { captured_user_prompt = p },
        capture_schema: ->(s) { captured_schema = s }
      )

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "completed", @edit_version.status
      assert_equal "## Novo plano\n\nFoco em força.", @edit_version.body_md

      by_position = @edit_version.workouts.order(:position).index_by(&:position)
      assert_equal 2, by_position.size, "previous workouts must NOT be carried forward"
      assert_equal %w[Push Pull], by_position.values.map(&:name)
      assert_equal [ 1, 2 ], by_position.keys

      assert_equal PeriodizationVersion::Generatable::SCHEMA, captured_schema
      assert_match(/Mesociclo base/, captured_user_prompt, "prompt must include the parent body as context")
      assert_match(/Supino/, captured_user_prompt, "prompt must include the parent workouts as context")
      assert_match(/foco em força/i, captured_user_prompt, "prompt must include the trainer transcript")
    end

    test "marks the edit version failed when the LLM response is missing required keys" do
      invalid_plan = { "body_md" => "ok" } # workouts missing
      fake_chat = build_fake_chat(content: invalid_plan)

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_match(/workouts/, @edit_version.error_message)
      assert_equal 0, @edit_version.workouts.count, "no workouts should be persisted on a failed edit"
    end

    test "marks the edit version failed when blocks are malformed" do
      bad_plan = {
        "body_md" => "## ok",
        "workouts" => [
          { "name" => "X", "position" => 1, "blocks" => [ { "kind" => "freeform" } ] } # missing text_md
        ]
      }
      fake_chat = build_fake_chat(content: bad_plan)

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_match(/text_md/, @edit_version.error_message)
    end

    test "marks the edit version failed when RubyLLM raises" do
      fake_chat = Object.new
      fake_chat.define_singleton_method(:with_instructions) { |_| self }
      fake_chat.define_singleton_method(:with_schema) { |_| self }
      fake_chat.define_singleton_method(:ask) { |_| raise RuntimeError, "Anthropic indisponível" }

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@edit_version)
      end

      @edit_version.reload
      assert_equal "failed", @edit_version.status
      assert_equal "Anthropic indisponível", @edit_version.error_message
    end

    private
      def exercise_block(name, prescription)
        { "kind" => "exercise", "name" => name, "prescription" => prescription }
      end

      def walk_recording_to_generating!(recording)
        recording.transition_to!(:transcribing)
        recording.transition_to!(:transcribed)
        recording.transition_to!(:generating)
      end

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

  # --- Editable target dispatch (mutate-in-place on draft) ---

  class EditableTargetTest < ActiveJob::TestCase
    setup do
      @organization = organizations(:steimfit)
      @organization.update!(equipment_list_md: "- Barra olímpica\n- Anilhas\n")

      @student = students(:alice)
      @student.update!(
        birthday: Date.new(1994, 1, 1), sex: "Feminino", primary_goal: "Hipertrofia",
        weekly_frequency: 3, restrictions_summary: "Lombar sensível",
        anamnesis_md: "## Histórico\n\nLevantamento básico há 2 anos."
      )
      @trainer = users(:one)

      create_recording = VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_create",
        transcript: "Plano inicial."
      )
      @promoted_version = @student.start_periodization!(trainer: @trainer, voice_recording: create_recording)
      @promoted_version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano\n\nMesociclo base.",
          workouts: [
            { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
            { name: "B", blocks: [ exercise_block("Supino reto", "4x8") ], position: 2 },
            { name: "C", blocks: [ exercise_block("Levantamento terra", "3x5") ], position: 3 }
          ]
        },
        trainer: @trainer,
        voice_recording: create_recording
      )
      @promoted_version.transition_to!(:completed)
      @promoted_version.periodization.set_current_version!(@promoted_version)

      # Build an editable draft (a fresh fork that's not promoted, not
      # superseded — this is the "working draft" the trainer is editing).
      @draft = @promoted_version.periodization.versions.create!(
        trainer: @trainer, voice_recording: nil, parent_version: @promoted_version
      )
      @draft.fork_with!(scope: :clone, patch: nil, trainer: @trainer)
      @draft.reload

      assert_not @draft.read_only?, "fixture sanity: draft must be editable"
    end

    test "run_workout_edit! with an editable target mutates the draft in place via apply_patch! and leaves no new version row" do
      target_workout = @draft.workouts.find_by(position: 2)

      edit_recording = VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_edit_workout",
        target_workout: target_workout,
        target_periodization_version: @draft,
        transcript: "Trocar supino reto por supino inclinado."
      )
      walk_recording_to_generating!(edit_recording)
      @draft.update!(voice_recording: edit_recording)
      @draft.transition_to!(:generating)

      valid_patch = {
        "workout" => {
          "name" => "B'",
          "blocks" => [ exercise_block("Supino inclinado", "4x10") ]
        }
      }
      fake_chat = build_fake_chat(content: valid_patch)

      versions_before = PeriodizationVersion.count

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@draft)
      end

      assert_equal versions_before, PeriodizationVersion.count, "no new PeriodizationVersion row should be created"

      @draft.reload
      assert_equal "completed", @draft.status
      by_position = @draft.workouts.order(:position).index_by(&:position)
      assert_equal "B'", by_position[2].name
      assert_equal "Supino inclinado", by_position[2].blocks.first["name"]
      assert_equal "A", by_position[1].name, "other workouts must remain byte-identical"
      assert_equal "C", by_position[3].name
      assert_equal edit_recording.id, @draft.voice_recording_id
      assert_equal "completed", edit_recording.reload.status
    end

    test "run_periodization_edit! with an editable target mutates the draft in place and leaves no new version row" do
      edit_recording = VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_edit_periodization",
        target_periodization_version: @draft,
        transcript: "Refazer com foco em força, dois treinos."
      )
      walk_recording_to_generating!(edit_recording)
      @draft.update!(voice_recording: edit_recording)
      @draft.transition_to!(:generating)

      valid_plan = {
        "body_md" => "## Novo plano\n\nFoco em força.",
        "workouts" => [
          { "name" => "Push", "position" => 1, "blocks" => [ exercise_block("Supino", "5x5") ] },
          { "name" => "Pull", "position" => 2, "blocks" => [ exercise_block("Remada", "5x5") ] }
        ]
      }
      fake_chat = build_fake_chat(content: valid_plan)

      versions_before = PeriodizationVersion.count

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@draft)
      end

      assert_equal versions_before, PeriodizationVersion.count, "no new PeriodizationVersion row should be created"

      @draft.reload
      assert_equal "completed", @draft.status
      assert_equal "## Novo plano\n\nFoco em força.", @draft.body_md
      assert_equal %w[Push Pull], @draft.workouts.order(:position).pluck(:name)
      assert_equal edit_recording.id, @draft.voice_recording_id
      assert_equal "completed", edit_recording.reload.status
    end

    test "run_workout_edit! failure on an editable target leaves the draft's body_md and workouts unchanged" do
      target_workout = @draft.workouts.find_by(position: 2)

      edit_recording = VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_edit_workout",
        target_workout: target_workout,
        target_periodization_version: @draft,
        transcript: "x"
      )
      walk_recording_to_generating!(edit_recording)
      @draft.update!(voice_recording: edit_recording)
      @draft.transition_to!(:generating)

      original_body_md = @draft.body_md
      original_workouts = @draft.workouts.order(:position).map { |w| [ w.name, w.blocks ] }

      fake_chat = build_fake_chat(content: { "body_md" => "wrong shape" }) # missing workout key

      RubyLLM.stub :chat, ->(*) { fake_chat } do
        GeneratePeriodizationJob.perform_now(@draft)
      end

      @draft.reload
      assert_equal original_body_md, @draft.body_md, "draft body_md must be unchanged on failure"
      assert_equal original_workouts, @draft.workouts.order(:position).map { |w| [ w.name, w.blocks ] },
                   "draft workouts must be unchanged on failure"
      assert_equal "failed", edit_recording.reload.status
      assert_match(/workout/, edit_recording.error_message)
    end

    private
      def exercise_block(name, prescription)
        { "kind" => "exercise", "name" => name, "prescription" => prescription }
      end

      def walk_recording_to_generating!(recording)
        recording.transition_to!(:transcribing)
        recording.transition_to!(:transcribed)
        recording.transition_to!(:generating)
      end

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
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end

    def walk_recording_to_generating!(recording)
      recording.transition_to!(:transcribing)
      recording.transition_to!(:transcribed)
      recording.transition_to!(:generating)
    end

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
