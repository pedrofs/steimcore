require "test_helper"

class Periodizations::EditsControllerTest < ActionDispatch::IntegrationTest
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
    @periodization = @version.periodization
    @periodization.set_current_version!(@version)
    @student.update!(active_periodization: @periodization)
  end

  test "create redirects to the recorder with target_periodization_version_id == current_version_id" do
    sign_in_as(@user)

    post periodization_edit_path(@periodization)

    assert_redirected_to new_student_voice_recording_path(
      @student,
      kind: "periodization_edit_periodization",
      target_periodization_version_id: @version.id
    )
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_student = other_org.students.create!(name: "Externo")
    other_periodization = other_student.periodizations.create!
    sign_in_as(@user)

    post periodization_edit_path(other_periodization)

    assert_response :not_found
  end
end
