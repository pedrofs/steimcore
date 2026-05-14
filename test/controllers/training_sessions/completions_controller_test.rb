require "test_helper"

class TrainingSessions::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:steimfit)
    @user = users(:one)
    @alice = students(:alice)
    @workouts = make_eligible(@alice, workout_count: 1)
    @session = @user.training_sessions.start_for!(@alice)
  end

  test "create requires authentication" do
    post training_session_completion_path(@session)
    assert_redirected_to new_session_path
  end

  test "create finishes the session" do
    sign_in_as(@user)

    post training_session_completion_path(@session)

    assert_redirected_to training_sessions_path
    assert_not_nil @session.reload.finished_at
  end

  test "destroy reopens the session" do
    @session.update!(finished_at: 1.minute.ago)

    sign_in_as(@user)

    delete training_session_completion_path(@session)

    assert_redirected_to training_sessions_path
    assert_nil @session.reload.finished_at
  end

  test "create allows another trainer in the same organization to finish the session" do
    other = users(:two)
    sign_in_as(other)

    post training_session_completion_path(@session)

    assert_redirected_to training_sessions_path
    assert_not_nil @session.reload.finished_at
  end

  test "create preserves trainer_id when another trainer in the same organization finishes" do
    other = users(:two)
    sign_in_as(other)

    post training_session_completion_path(@session)

    assert_equal @user.id, @session.reload.trainer_id
  end

  test "create rejects a trainer from a different organization with 404" do
    other_org  = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    sign_in_as(other_user)

    post training_session_completion_path(@session)

    assert_response :not_found
    assert_nil @session.reload.finished_at
  end

  private
    def make_eligible(student, workout_count:, blocks: [])
      version = student.start_periodization!(trainer: @user)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: blocks)
      end
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end
end
