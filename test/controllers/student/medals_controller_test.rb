require "test_helper"

class Student::MedalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @student = @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
  end

  test "index renders the four families, collapsing each to the highest earned tier" do
    @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 6, earned_at: Time.current)
    @student.student_medals.create!(family: "workouts", tier: 5, value_snapshot: 6, earned_at: Time.current)
    sign_in_with_selected_profile(@identity, @student)

    get student_medals_path

    assert_response :success
    assert_equal "student/medals/index", inertia.component

    families = inertia.props[:families]
    assert_equal %w[workouts weekly_streak full_weeks periodizations], families.map { |f| f[:key] }

    workouts = families.find { |f| f[:key] == "workouts" }
    assert_equal 5, workouts[:highest_tier]
    assert_not workouts[:locked]

    locked = families.find { |f| f[:key] == "weekly_streak" }
    assert locked[:locked]
    assert_nil locked[:highest_tier]
  end

  test "redirects to the student sign-in when not authenticated" do
    get student_medals_path

    assert_redirected_to new_student_session_path
  end

  private
    def sign_in_with_selected_profile(identity, student)
      sign_in_as(identity)
      identity.sessions.sole.update!(selected_student: student)
    end
end
