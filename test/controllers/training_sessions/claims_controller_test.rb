require "test_helper"

class TrainingSessions::ClaimsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:steimfit)
    @user = users(:one)
    @alice = students(:alice)
    make_eligible(@alice, workout_count: 1)
  end

  test "create requires authentication" do
    session = TrainingSession.start!(student: @alice)

    post training_session_claim_path(session)

    assert_redirected_to new_session_path
    assert_nil session.reload.trainer_id
  end

  test "create claims a student-started session for the current trainer" do
    session = TrainingSession.start!(student: @alice)
    sign_in_as(@user)

    post training_session_claim_path(session)

    assert_redirected_to training_sessions_path
    assert_equal @user.id, session.reload.trainer_id
  end

  test "create lets another trainer claim a session owned by someone else" do
    session = @user.training_sessions.start_for!(@alice)
    other = users(:two)
    sign_in_as(other)

    post training_session_claim_path(session)

    assert_redirected_to training_sessions_path
    assert_equal other.id, session.reload.trainer_id
  end

  test "create rejects a trainer from a different organization with 404" do
    session = TrainingSession.start!(student: @alice)
    other_org  = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    sign_in_as(other_user)

    post training_session_claim_path(session)

    assert_response :not_found
    assert_nil session.reload.trainer_id
  end

  private
    def make_eligible(student, workout_count:, blocks: [])
      version = student.start_periodization!(trainer: @user)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: blocks)
      end
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end
end
