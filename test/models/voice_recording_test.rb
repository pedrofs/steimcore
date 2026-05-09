require "test_helper"

class VoiceRecordingTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "requires kind, organization, student, and trainer" do
    recording = VoiceRecording.new

    assert_not recording.valid?
    assert_includes recording.errors[:organization], "must exist"
    assert_includes recording.errors[:student], "must exist"
    assert_includes recording.errors[:trainer], "must exist"
    assert_includes recording.errors[:kind], "can't be blank"
  end

  test "rejects unknown kind" do
    recording = build_recording(kind: "wat")

    assert_not recording.valid?
    assert_includes recording.errors[:kind].join, "is not included"
  end

  test "confirm_transcript! writes the edited transcript and enqueues the next job" do
    recording = build_recording
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "ascii fallback")
    recording.transition_to!(:transcribed)

    assert_enqueued_with(job: RegenerateAnamnesisJob, args: [ recording.id ]) do
      recording.confirm_transcript!("Aluno relatou dor na lombar há 3 meses.")
    end

    recording.reload
    assert_equal "Aluno relatou dor na lombar há 3 meses.", recording.transcript
    assert_not_nil recording.transcript_edited_at
    assert_equal "generating", recording.status
  end

  test "fail! moves to :failed with error_message" do
    recording = build_recording
    recording.transition_to!(:transcribing)

    recording.fail!("Whisper indisponível")

    recording.reload
    assert_equal "failed", recording.status
    assert_equal "Whisper indisponível", recording.error_message
  end

  private
    def build_recording(**overrides)
      VoiceRecording.create!(
        organization: @organization,
        student: @student,
        trainer: @trainer,
        kind: "anamnesis",
        **overrides
      )
    rescue ActiveRecord::RecordInvalid
      VoiceRecording.new(
        organization: @organization,
        student: @student,
        trainer: @trainer,
        kind: "anamnesis",
        **overrides
      )
    end
end
