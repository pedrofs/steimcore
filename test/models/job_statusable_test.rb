require "test_helper"

# Exercises JobStatusable through VoiceRecording — the concern is meaningless
# without a host model, so tests assert behaviour through one.
class JobStatusableTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "voice recordings start in :pending by default" do
    recording = build_recording

    assert_equal "pending", recording.status
  end

  test "legal transitions for the anamnesis lifecycle are accepted" do
    recording = create_recording

    %w[transcribing transcribed generating completed].each do |next_status|
      recording.transition_to!(next_status)
      assert_equal next_status, recording.reload.status
    end
  end

  test "illegal transitions are rejected with a validation error" do
    recording = create_recording

    recording.status = "completed"

    assert_not recording.valid?
    assert_includes recording.errors[:status].join, "cannot transition from \"pending\" to \"completed\""
  end

  test "skipping intermediate states is rejected" do
    recording = create_recording
    recording.transition_to!(:transcribing)

    recording.status = "completed"

    assert_not recording.valid?
    assert_includes recording.errors[:status].join, "cannot transition"
  end

  test "transitioning to :failed without an error_message is rejected" do
    recording = create_recording

    recording.status = "failed"

    assert_not recording.valid?
    assert_includes recording.errors[:error_message], "is required when status is failed"
  end

  test "transitioning to :failed with an error_message succeeds" do
    recording = create_recording

    recording.error_message = "Whisper indisponível"
    recording.transition_to!(:failed)

    assert_equal "failed", recording.reload.status
  end

  test "failed recordings can be retried by re-entering :transcribing" do
    recording = create_recording
    recording.update!(error_message: "Boom")
    recording.transition_to!(:failed)

    recording.transition_to!(:transcribing)

    assert_equal "transcribing", recording.reload.status
  end

  test "unknown statuses are rejected" do
    recording = create_recording

    recording.status = "wat"

    assert_not recording.valid?
    assert_includes recording.errors[:status].join, "is not included"
  end

  private
    def build_recording
      VoiceRecording.new(
        organization: @organization,
        student: @student,
        trainer: @trainer,
        kind: "anamnesis"
      )
    end

    def create_recording
      build_recording.tap(&:save!)
    end
end
