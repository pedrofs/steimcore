require "test_helper"

class Student::WorkoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @student = @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
    @trainer = users(:one)
  end

  test "index renders the current version's workouts for a signed-in selected profile" do
    promote_plan_for(@student)
    sign_in_with_selected_profile(@identity, @student)

    get student_workouts_path

    assert_response :success
    assert_equal "student/workouts/index", inertia.component
    assert_equal [ "Treino A", "Treino B" ], inertia.props[:workouts].map { |w| w[:name] }
  end

  test "index renders an empty workouts list when there is no readable plan" do
    sign_in_with_selected_profile(@identity, @student)

    get student_workouts_path

    assert_response :success
    assert_equal "student/workouts/index", inertia.component
    assert_equal [], inertia.props[:workouts]
  end

  test "redirects to the student sign-in when not authenticated" do
    get student_workouts_path

    assert_redirected_to new_student_session_path
  end

  test "bounces to the no-profile page when the only selected student is destroyed mid-session" do
    sign_in_with_selected_profile(@identity, @student)
    @student.destroy!

    get student_workouts_path

    assert_redirected_to student_no_profile_path
  end

  private
    def sign_in_with_selected_profile(identity, student)
      sign_in_as(identity)
      identity.sessions.sole.update!(selected_student: student)
    end

    def promote_plan_for(student)
      periodization = student.periodizations.create!
      version = periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
      version.workouts.create!(name: "Treino A", position: 1, blocks: [
        { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" }
      ])
      version.workouts.create!(name: "Treino B", position: 2, blocks: [])
      periodization.set_current_version!(version)
      student.update!(active_periodization: periodization)
    end
end
