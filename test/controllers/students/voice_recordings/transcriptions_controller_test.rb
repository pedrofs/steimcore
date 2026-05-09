require "test_helper"

class Students::VoiceRecordings::TranscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "anamnesis"
    )
  end

  test "create re-enqueues TranscribeJob for a failed recording" do
    @recording.update!(error_message: "Whisper indisponível")
    @recording.transition_to!(:failed)
    sign_in_as(@user)

    assert_enqueued_with(job: TranscribeJob, args: [ @recording.id ]) do
      post student_voice_recording_transcription_path(@student, @recording)
    end

    @recording.reload
    assert_equal "transcribing", @recording.status
    assert_nil @recording.error_message
    assert_redirected_to student_voice_recording_path(@student, @recording)
  end

  test "create on a non-failed recording is a no-op" do
    sign_in_as(@user)

    assert_no_enqueued_jobs(only: TranscribeJob) do
      post student_voice_recording_transcription_path(@student, @recording)
    end

    @recording.reload
    assert_equal "pending", @recording.status
    assert_redirected_to student_voice_recording_path(@student, @recording)
  end
end
