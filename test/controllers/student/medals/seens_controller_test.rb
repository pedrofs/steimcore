require "test_helper"

class Student::Medals::SeensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @student = @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
  end

  test "create marks the medal seen and redirects back to the Medalhas page" do
    medal = @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: Time.current)
    sign_in_with_selected_profile(@identity, @student)

    assert_changes -> { medal.reload.seen_at }, from: nil do
      post student_medal_seen_path(medal)
    end

    assert_redirected_to student_medals_path
  end

  test "create is scoped to the selected profile's own medals" do
    foreign_medal = students(:bob).student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: Time.current)
    sign_in_with_selected_profile(@identity, @student)

    post student_medal_seen_path(foreign_medal)

    assert_response :not_found
    assert_nil foreign_medal.reload.seen_at
  end

  test "redirects to the student sign-in when not authenticated" do
    medal = @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: Time.current)

    post student_medal_seen_path(medal)

    assert_redirected_to new_student_session_path
  end

  private
    def sign_in_with_selected_profile(identity, student)
      sign_in_as(identity)
      identity.sessions.sole.update!(selected_student: student)
    end
end
