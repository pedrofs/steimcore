require "test_helper"

class PeriodizationVersions::PromotionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "periodization_create"
    )
    @version = @student.start_periodization!(trainer: @user, voice_recording: @recording)
    @version.fork_with!(
      scope: :create,
      patch: {
        body_md: "## Plano",
        workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "Agachamento", prescription: "4x8" } ], position: 1 } ]
      },
      trainer: @user,
      voice_recording: @recording
    )
  end

  test "create promotes a completed version and redirects to the periodization" do
    @version.transition_to!(:completed)
    sign_in_as(@user)

    post periodization_version_promotion_path(@version)

    @version.reload
    assert_redirected_to student_periodization_path(@student, @version.periodization)
    assert_equal @version.id, @version.periodization.reload.current_version_id
  end

  test "create refuses to promote a non-completed version" do
    sign_in_as(@user)

    post periodization_version_promotion_path(@version)

    assert_redirected_to periodization_version_path(@version)
    assert_nil @version.periodization.reload.current_version_id
  end

  test "create honors a same-origin return_to query param" do
    @version.transition_to!(:completed)
    sign_in_as(@user)

    post periodization_version_promotion_path(@version),
         params: { return_to: student_agent_chat_path(@student, open_version_id: @version.id) }

    assert_redirected_to student_agent_chat_path(@student, open_version_id: @version.id)
  end

  test "create ignores an absolute-URL return_to and falls back to the periodization page" do
    @version.transition_to!(:completed)
    sign_in_as(@user)

    post periodization_version_promotion_path(@version),
         params: { return_to: "https://evil.example.com/steal" }

    assert_redirected_to student_periodization_path(@student, @version.periodization)
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_recording = VoiceRecording.create!(
      organization: other_org,
      student: foreign_student,
      trainer: User.create!(email_address: "x@y.com", password: "password", organization: other_org),
      kind: "periodization_create"
    )
    foreign_version = foreign_student.start_periodization!(trainer: foreign_recording.trainer, voice_recording: foreign_recording)
    sign_in_as(@user)

    post periodization_version_promotion_path(foreign_version)

    assert_response :not_found
  end
end
