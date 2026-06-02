require "test_helper"

class Student::TrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @student = @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
    build_active_plan!
  end

  test "create on a weekday starts a trainer-less session and lands on the live screen" do
    sign_in_with_selected_profile(@identity, @student)

    travel_to monday do
      post student_training_sessions_path

      session = @student.training_sessions.active.sole
      assert_nil session.trainer_id
      assert_redirected_to student_training_session_path(session)
    end
  end

  test "create on a weekend is rejected server-side and redirects home with an alert" do
    sign_in_with_selected_profile(@identity, @student)

    travel_to saturday do
      assert_no_difference -> { @student.training_sessions.count } do
        post student_training_sessions_path
      end

      assert_redirected_to student_home_path
      assert_match(/descanso/i, flash[:alert])
    end
  end

  test "create resolves a duplicate active session to the existing one instead of erroring" do
    sign_in_with_selected_profile(@identity, @student)

    travel_to monday do
      existing = TrainingSession.start!(student: @student, trainer: users(:one))

      post student_training_sessions_path

      assert_equal 1, @student.training_sessions.active.count
      assert_redirected_to student_training_session_path(existing)
    end
  end

  test "show renders the live screen for the student's session" do
    sign_in_with_selected_profile(@identity, @student)

    travel_to monday do
      session = @student.start_training_session!

      get student_training_session_path(session)

      assert_response :success
      assert_equal "student/training_sessions/show", inertia.component
      assert_equal session.id, inertia.props[:session][:id]
      assert_equal "student", inertia.props[:session][:initiator]
    end
  end

  test "show cannot reach another student's session" do
    sign_in_with_selected_profile(@identity, @student)
    other = organizations(:steimfit).students.create!(name: "Other", email: "other@example.com")
    other_plan_version = build_active_plan_for!(other)
    other_session = TrainingSession.start!(student: other, trainer: users(:one), workout: other_plan_version.workouts.first)

    get student_training_session_path(other_session)

    assert_response :not_found
  end

  test "create requires a selected profile" do
    sign_in_as(@identity)

    post student_training_sessions_path

    assert_redirected_to new_student_profile_selection_path
  end

  private
    def monday
      Time.zone.local(2026, 6, 1, 10, 0, 0)
    end

    def saturday
      Time.zone.local(2026, 6, 6, 10, 0, 0)
    end

    def sign_in_with_selected_profile(identity, student)
      sign_in_as(identity)
      identity.sessions.sole.update!(selected_student: student)
    end

    def build_active_plan!
      build_active_plan_for!(@student)
    end

    def build_active_plan_for!(student)
      periodization = student.periodizations.create!
      version = periodization.versions.create!(
        trainer: users(:one), status: "completed", periodization_length_weeks: 8
      )
      version.workouts.create!(name: "Treino A", position: 1, blocks: [
        { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" }
      ])
      periodization.set_current_version!(version)
      student.update!(active_periodization: periodization)
      version
    end
end
