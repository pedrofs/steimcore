require "test_helper"

class Students::VoiceRecordings::RetriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "anamnesis"
    )
    @recording.transition_to!(:transcribing)
    @recording.fail!("Whisper indisponível")
  end

  test "create re-enqueues a kind-appropriate job and redirects to the recording show page" do
    sign_in_as(@user)

    assert_enqueued_with(job: TranscribeJob, args: [ @recording ]) do
      post student_voice_recording_retry_path(@student, @recording)
    end

    @recording.reload
    assert_equal "pending", @recording.status
    assert_nil @recording.error_message
    assert_redirected_to student_voice_recording_path(@student, @recording)
  end

  test "create on a non-failed recording is a no-op redirect" do
    pending = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "anamnesis"
    )
    sign_in_as(@user)

    assert_no_enqueued_jobs do
      post student_voice_recording_retry_path(@student, pending)
    end

    assert_equal "pending", pending.reload.status
    assert_redirected_to student_voice_recording_path(@student, pending)
  end
end
