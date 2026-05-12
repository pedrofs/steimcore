require "test_helper"

class PeriodizationVersions::EditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    seed_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "periodization_create", transcript: "x"
    )
    @version = @student.start_periodization!(trainer: @user, voice_recording: seed_recording)
    @version.fork_with!(
      scope: :create,
      patch: {
        body_md: "## Plano",
        workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "Supino", prescription: "3x8" } ], position: 1 } ]
      },
      trainer: @user, voice_recording: seed_recording
    )
    @version.reload
  end

  test "create redirects to the recorder with target_periodization_version_id == this version" do
    sign_in_as(@user)

    post periodization_version_edit_path(@version)

    assert_redirected_to new_student_voice_recording_path(
      @student,
      kind: "periodization_edit_periodization",
      target_periodization_version_id: @version.id
    )
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_student = other_org.students.create!(name: "Externo")
    other_recording = VoiceRecording.create!(
      organization: other_org, student: other_student,
      trainer: User.create!(email_address: "x@y.com", password: "password", organization: other_org),
      kind: "periodization_create", transcript: "x"
    )
    other_version = other_student.start_periodization!(trainer: other_recording.trainer, voice_recording: other_recording)
    sign_in_as(@user)

    post periodization_version_edit_path(other_version)

    assert_response :not_found
  end
end
