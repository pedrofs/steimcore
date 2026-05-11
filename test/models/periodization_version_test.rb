require "test_helper"

class PeriodizationVersionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @periodization = @student.periodizations.create!
  end

  test "starts in :generating once a transition is invoked from :pending" do
    version = build_version

    assert_equal "pending", version.status

    version.transition_to!(:generating)

    assert_equal "generating", version.reload.status
  end

  test "rejects skipping straight from :pending to :completed" do
    version = build_version
    version.status = "completed"

    assert_not version.valid?
    assert_includes version.errors[:status].join, "cannot transition"
  end

  test "fail! requires an error_message and lands in :failed" do
    version = build_version
    version.transition_to!(:generating)

    version.fail!("Anthropic indisponível")

    assert_equal "failed", version.reload.status
    assert_equal "Anthropic indisponível", version.error_message
  end

  test "promoted? is true once the periodization points at this version" do
    version = build_version
    assert_not version.promoted?

    @periodization.update!(current_version: version)

    assert version.reload.promoted?
  end

  test "complete! transitions the version to :completed and bubbles to the voice recording" do
    recording = build_recording_in_generating
    version = build_version(voice_recording: recording)
    version.transition_to!(:generating)

    version.complete!

    assert_equal "completed", version.reload.status
    assert_equal "completed", recording.reload.status, "complete! must bubble to the voice recording"
  end

  test "fail! transitions the version to :failed and bubbles failure (with the same message) to the voice recording" do
    recording = build_recording_in_generating
    version = build_version(voice_recording: recording)
    version.transition_to!(:generating)

    version.fail!("Anthropic indisponível")

    assert_equal "failed", version.reload.status
    recording.reload
    assert_equal "failed", recording.status
    assert_equal "Anthropic indisponível", recording.error_message
  end

  private
    def build_version(voice_recording: nil)
      @periodization.versions.create!(
        trainer: @trainer,
        voice_recording: voice_recording,
        parent_version: nil
      )
    end

    def build_recording_in_generating
      recording = VoiceRecording.create!(
        organization: @organization,
        student: @student,
        trainer: @trainer,
        kind: "periodization_create"
      )
      recording.transition_to!(:transcribing)
      recording.transition_to!(:transcribed)
      recording.transition_to!(:generating)
      recording
    end
end
