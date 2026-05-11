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

  test "confirm_transcript! is not part of the public surface" do
    recording = build_recording

    assert_not recording.public_methods.include?(:confirm_transcript!),
      "confirm_transcript! must be private (invoked by Transcribable#transcribe!), not a public action"
  end

  test "periodization_edit_workout requires a target_workout" do
    recording = VoiceRecording.new(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_workout"
    )

    assert_not recording.valid?
    assert_includes recording.errors[:target_workout], "can't be blank"
  end

  test "fail! moves to :failed with error_message" do
    recording = build_recording
    recording.transition_to!(:transcribing)

    recording.fail!("Whisper indisponível")

    recording.reload
    assert_equal "failed", recording.status
    assert_equal "Whisper indisponível", recording.error_message
  end

  test "allows the new failed -> generating transition (smart retry under transcript-present failures)" do
    recording = build_recording
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Aluno cita dor lombar.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    recording.fail!("LLM indisponível")

    assert_equal "failed", recording.reload.status
    recording.error_message = nil
    recording.transition_to!(:generating)

    assert_equal "generating", recording.reload.status
  end

  test "exposes the associated periodization_version through has_one" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    version = @student.start_periodization!(trainer: @trainer, voice_recording: recording)

    assert_equal version, recording.reload.periodization_version
  end

  test "purge_audio_older_than purges only recordings older than the cutoff with audio attached, leaving transcripts intact" do
    old_with_audio = build_recording
    old_with_audio.audio.attach(io: StringIO.new("old"), filename: "old.webm", content_type: "audio/webm")
    old_with_audio.update!(transcript: "transcrição antiga")
    old_with_audio.update_columns(created_at: 8.days.ago)

    new_with_audio = build_recording
    new_with_audio.audio.attach(io: StringIO.new("new"), filename: "new.webm", content_type: "audio/webm")
    new_with_audio.update!(transcript: "transcrição recente")
    new_with_audio.update_columns(created_at: 1.day.ago)

    old_without_audio = build_recording
    old_without_audio.update!(transcript: "sem áudio")
    old_without_audio.update_columns(created_at: 10.days.ago)

    perform_enqueued_jobs do
      assert_nothing_raised do
        VoiceRecording.purge_audio_older_than(7.days)
      end
    end

    assert_not old_with_audio.reload.audio.attached?, "old recording's audio should have been purged"
    assert new_with_audio.reload.audio.attached?, "recent recording's audio should remain attached"
    assert_not old_without_audio.reload.audio.attached?, "recording without audio should remain detached (no error)"

    assert_equal "transcrição antiga", old_with_audio.transcript
    assert_equal "transcrição recente", new_with_audio.transcript
    assert_equal "sem áudio", old_without_audio.transcript
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
