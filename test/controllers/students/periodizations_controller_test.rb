require "test_helper"

class Students::PeriodizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "new redirects to the voice recording flow with kind=periodization_create" do
    sign_in_as(@user)

    get new_student_periodization_path(@student)

    assert_redirected_to new_student_voice_recording_path(@student, kind: "periodization_create")
  end

  test "new is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    get new_student_periodization_path(foreign_student)

    assert_response :not_found
  end

  test "show renders the active periodization with body and workouts" do
    recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "periodization_create"
    )
    version = @student.start_periodization!(trainer: @user, voice_recording: recording)
    version.fork_with!(
      scope: :create,
      patch: {
        body_md: "## Plano",
        workouts: [
          { name: "A", content_md: "ag 4x8", position: 1 },
          { name: "B", content_md: "sup 4x8", position: 2 }
        ]
      },
      trainer: @user,
      voice_recording: recording
    )
    version.transition_to!(:completed)
    periodization = version.periodization
    periodization.update!(current_version: version)

    sign_in_as(@user)
    get student_periodization_path(@student, periodization)

    assert_response :success
    assert_equal "students/periodizations/show", inertia.component
    props = inertia.props[:periodization]
    assert_equal periodization.id, props[:id]
    assert_equal "## Plano", props[:current_version][:body_md]
    assert_equal %w[A B], props[:current_version][:workouts].map { |w| w[:name] }
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_periodization = foreign_student.periodizations.create!
    sign_in_as(@user)

    get student_periodization_path(foreign_student, foreign_periodization)

    assert_response :not_found
  end
end
