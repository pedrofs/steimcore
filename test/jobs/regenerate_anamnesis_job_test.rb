require "test_helper"

class RegenerateAnamnesisJobTest < ActiveJob::TestCase
  setup do
    @student = students(:alice)
    @student.update!(
      age: 32,
      sex: "Feminino",
      primary_goal: "Hipertrofia",
      restrictions_summary: "Lombar sensível",
      anamnesis_md: "## Histórico\n\nLesão antiga na lombar."
    )

    @recording = VoiceRecording.create!(
      organization: organizations(:steimfit),
      student: @student,
      trainer: users(:one),
      kind: "anamnesis",
      transcript: "Aluno relatou ontem dor no joelho direito ao agachar."
    )
    @recording.transition_to!(:transcribing)
    @recording.transition_to!(:transcribed)
    @recording.transition_to!(:generating)
  end

  test "writes the merged proposed anamnesis onto the recording without touching the student" do
    chat_response = Struct.new(:content).new("## Histórico\n\nLesão antiga na lombar.\n\n## Restrições\n\n- Joelho direito sensível ao agachar.\n")

    captured_user_prompt = nil
    fake_chat = Object.new
    fake_chat.define_singleton_method(:with_instructions) { |_| self }
    fake_chat.define_singleton_method(:ask) do |prompt|
      captured_user_prompt = prompt
      chat_response
    end

    original_anamnesis = @student.anamnesis_md

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      RegenerateAnamnesisJob.perform_now(@recording)
    end

    @recording.reload
    @student.reload

    assert_match(/Joelho direito/, @recording.proposed_anamnesis_md)
    assert_equal "completed", @recording.status
    assert_nil @recording.error_message
    assert_equal original_anamnesis, @student.anamnesis_md, "student record must not change until trainer commits"

    assert_match(/Lesão antiga na lombar/, captured_user_prompt)
    assert_match(/dor no joelho direito/, captured_user_prompt)
    assert_match(/Hipertrofia/, captured_user_prompt)
  end

  test "marks the recording as failed when RubyLLM raises and leaves the student untouched" do
    fake_chat = Object.new
    fake_chat.define_singleton_method(:with_instructions) { |_| self }
    fake_chat.define_singleton_method(:ask) { |_| raise RuntimeError, "Anthropic indisponível" }

    original_anamnesis = @student.anamnesis_md

    RubyLLM.stub :chat, ->(*) { fake_chat } do
      RegenerateAnamnesisJob.perform_now(@recording)
    end

    @recording.reload
    @student.reload

    assert_equal "failed", @recording.status
    assert_equal "Anthropic indisponível", @recording.error_message
    assert_nil @recording.proposed_anamnesis_md
    assert_equal original_anamnesis, @student.anamnesis_md
  end

  test "is idempotent — running on a non-generating recording is a no-op" do
    @recording.update!(proposed_anamnesis_md: "preexisting")
    @recording.transition_to!(:completed)

    called = false
    RubyLLM.stub :chat, ->(*) { called = true; Object.new } do
      RegenerateAnamnesisJob.perform_now(@recording)
    end

    assert_not called
    assert_equal "completed", @recording.reload.status
    assert_equal "preexisting", @recording.proposed_anamnesis_md
  end
end
