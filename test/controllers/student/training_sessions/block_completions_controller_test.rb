require "test_helper"

class Student::TrainingSessions::BlockCompletionsControllerTest < ActionDispatch::IntegrationTest
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
    session = TrainingSession.start!(student: @student, trainer: users(:one))

    post student_training_session_block_completions_path(session), params: { block_index: "0" }

    assert_redirected_to new_student_session_path
  end

  test "create marks the block done and redirects back to the live screen" do
    sign_in_with_selected_profile(@identity, @student)
    session = TrainingSession.start!(student: @student, trainer: users(:one))

    post student_training_session_block_completions_path(session), params: { block_index: "1" }

    assert_redirected_to student_training_session_path(session)
    assert_equal [ "1" ], session.reload.progress
  end

  test "destroy unmarks the block and redirects back to the live screen" do
    sign_in_with_selected_profile(@identity, @student)
    session = TrainingSession.start!(student: @student, trainer: users(:one))
    session.mark_block_done!("1")

    delete student_training_session_block_completion_path(session, "1")

    assert_redirected_to student_training_session_path(session)
    assert_equal [], session.reload.progress
  end

  test "create works on a student-initiated session" do
    sign_in_with_selected_profile(@identity, @student)
    session = TrainingSession.start!(student: @student)

    post student_training_session_block_completions_path(session), params: { block_index: "0" }

    assert_equal [ "0" ], session.reload.progress
  end

  test "create rejects an out-of-range block_index with a flash alert" do
    sign_in_with_selected_profile(@identity, @student)
    session = TrainingSession.start!(student: @student, trainer: users(:one))

    post student_training_session_block_completions_path(session), params: { block_index: "99" }

    assert_redirected_to student_training_session_path(session)
    assert_equal [], session.reload.progress
  end

  test "create cannot reach another student's session" do
    sign_in_with_selected_profile(@identity, @student)
    other = organizations(:steimfit).students.create!(name: "Other", email: "other@example.com")
    other_version = build_active_plan_for!(other)
    other_session = TrainingSession.start!(student: other, trainer: users(:one), workout: other_version.workouts.first)

    post student_training_session_block_completions_path(other_session), params: { block_index: "0" }

    assert_response :not_found
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
        { "kind" => "exercise", "name" => "Supino",     "prescription" => "4x10" },
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x8" }
      ])
      periodization.set_current_version!(version)
      student.update!(active_periodization: periodization)
      version
    end
end
