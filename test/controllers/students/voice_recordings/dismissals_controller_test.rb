require "test_helper"

class Students::VoiceRecordings::DismissalsControllerTest < ActionDispatch::IntegrationTest
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

  test "create marks the recording dismissed and redirects to the inbox" do
    sign_in_as(@user)

    post student_voice_recording_dismissal_path(@student, @recording)

    assert_not_nil @recording.reload.dismissed_at
    assert_redirected_to inbox_path
  end

  test "create on a non-failed recording is a no-op redirect" do
    pending = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "anamnesis"
    )
    sign_in_as(@user)

    post student_voice_recording_dismissal_path(@student, pending)

    assert_nil pending.reload.dismissed_at
    assert_redirected_to inbox_path
  end
end
