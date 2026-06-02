require "test_helper"

class Student::TrainingSessions::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @student = @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
    @version = build_active_plan_for!(@student)
  end

  test "create requires authentication" do
    session = TrainingSession.start!(student: @student)

    post student_training_session_completion_path(session)

    assert_redirected_to new_student_session_path
  end

  test "create finishes a student-initiated session and lands on home" do
    sign_in_with_selected_profile(@identity, @student)
    session = TrainingSession.start!(student: @student)

    assert_changes -> { session.reload.finished_at }, from: nil do
      post student_training_session_completion_path(session)
    end

    assert_redirected_to student_home_path
    assert_not_nil session.reload.finished_at
  end

  test "create finishes a trainer-initiated session too" do
    sign_in_with_selected_profile(@identity, @student)
    session = TrainingSession.start!(student: @student, trainer: users(:one))

    post student_training_session_completion_path(session)

    assert_not_nil session.reload.finished_at
  end

  test "finishing counts toward the home trained-today state" do
    sign_in_with_selected_profile(@identity, @student)

    travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
      session = @student.start_training_session!
      post student_training_session_completion_path(session)

      assert Student::DashboardView.new(@student.reload).to_h[:trained_today]
    end
  end

  test "create cannot reach another student's session" do
    sign_in_with_selected_profile(@identity, @student)
    other = organizations(:steimfit).students.create!(name: "Other", email: "other@example.com")
    other_version = build_active_plan_for!(other)
    other_session = TrainingSession.start!(student: other, trainer: users(:one), workout: other_version.workouts.first)

    post student_training_session_completion_path(other_session)

    assert_response :not_found
    assert_nil other_session.reload.finished_at
  end

  private
    def sign_in_with_selected_profile(identity, student)
      sign_in_as(identity)
      identity.sessions.sole.update!(selected_student: student)
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
