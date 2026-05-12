require "test_helper"

class PeriodizationVersions::Workouts::EditsControllerTest < ActionDispatch::IntegrationTest
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
    @version.periodization.set_current_version!(@version)
    @workout = @version.workouts.first
  end

  test "create redirects to the recorder with target_periodization_version_id == workout.periodization_version_id" do
    sign_in_as(@user)

    post periodization_version_workout_edit_path(@version, @workout)

    assert_redirected_to new_student_voice_recording_path(
      @student,
      kind: "periodization_edit_workout",
      target_workout_id: @workout.id,
      target_periodization_version_id: @workout.periodization_version_id
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
    other_version.fork_with!(
      scope: :create,
      patch: {
        body_md: "## Plano",
        workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "Supino", prescription: "3x8" } ], position: 1 } ]
      },
      trainer: other_recording.trainer, voice_recording: other_recording
    )
    other_workout = other_version.reload.workouts.first
    sign_in_as(@user)

    post periodization_version_workout_edit_path(other_version, other_workout)

    assert_response :not_found
  end
end
