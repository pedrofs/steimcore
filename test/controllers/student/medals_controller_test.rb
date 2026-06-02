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

  test "index exposes the unseen medals queue in earned_at order, with family order breaking ties" do
    tie = Time.current
    # full_weeks comes after weekly_streak in the registry, so the same-instant
    # pair must order weekly_streak first regardless of insertion order.
    @student.student_medals.create!(family: "full_weeks", tier: 1, value_snapshot: 1, earned_at: tie, seen_at: nil)
    @student.student_medals.create!(family: "weekly_streak", tier: 2, value_snapshot: 2, earned_at: tie, seen_at: nil)
    @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: 1.hour.ago, seen_at: nil)
    # An already-seen medal never joins the celebration queue.
    @student.student_medals.create!(family: "workouts", tier: 5, value_snapshot: 6, earned_at: 2.hours.ago, seen_at: Time.current)
    sign_in_with_selected_profile(@identity, @student)

    get student_medals_path

    unseen = inertia.props[:unseen_medals]
    assert_equal %w[workouts weekly_streak full_weeks], unseen.map { |m| m[:family] }
    workouts = unseen.first
    assert_equal "Treinos", workouts[:name]
    assert_equal 1, workouts[:count]
    assert_equal 0, workouts[:tier_index]
    assert_equal 8, workouts[:tier_count]
  end

  test "index reports the unseen medal count as a shared prop for the nav dot" do
    @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: Time.current, seen_at: nil)
    @student.student_medals.create!(family: "workouts", tier: 5, value_snapshot: 6, earned_at: Time.current, seen_at: Time.current)
    sign_in_with_selected_profile(@identity, @student)

    get student_medals_path

    assert_equal 1, inertia.props[:unseen_medals_count]
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
