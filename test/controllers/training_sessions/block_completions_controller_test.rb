require "test_helper"

class TrainingSessions::BlockCompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:steimfit)
    @user = users(:one)
    @alice = students(:alice)
    @workouts = make_eligible(@alice, workout_count: 1, blocks: three_exercise_blocks)
    @session = @user.training_sessions.start_for!(@alice)
  end

  test "create requires authentication" do
    post training_session_block_completions_path(@session), params: { block_index: "0" }
    assert_redirected_to new_session_path
  end

  test "create marks the block done and redirects back" do
    sign_in_as(@user)

    post training_session_block_completions_path(@session), params: { block_index: "1" }

    assert_redirected_to training_sessions_path
    assert_equal [ "1" ], @session.reload.progress
  end

  test "create is idempotent — marking twice keeps a single entry" do
    sign_in_as(@user)

    post training_session_block_completions_path(@session), params: { block_index: "1" }
    post training_session_block_completions_path(@session), params: { block_index: "1" }

    assert_equal [ "1" ], @session.reload.progress
  end

  test "create rejects an out-of-range block_index with a flash alert" do
    sign_in_as(@user)

    post training_session_block_completions_path(@session), params: { block_index: "99" }

    assert_redirected_to training_sessions_path
    follow_redirect!
    assert_match(/bloco/i, flash[:alert] || "")
    assert_equal [], @session.reload.progress
  end

  test "create rejects a malformed block_index with a flash alert" do
    sign_in_as(@user)

    post training_session_block_completions_path(@session), params: { block_index: "1.0" }

    assert_redirected_to training_sessions_path
    follow_redirect!
    assert_match(/bloco/i, flash[:alert] || "")
    assert_equal [], @session.reload.progress
  end

  test "create allows another trainer in the same organization to mark a block" do
    other = users(:two)
    sign_in_as(other)

    post training_session_block_completions_path(@session), params: { block_index: "0" }

    assert_redirected_to training_sessions_path
    assert_equal [ "0" ], @session.reload.progress
  end

  test "create preserves trainer_id when another trainer in the same organization marks a block" do
    other = users(:two)
    sign_in_as(other)

    post training_session_block_completions_path(@session), params: { block_index: "0" }

    assert_equal @user.id, @session.reload.trainer_id
  end

  test "create rejects a trainer from a different organization with 404" do
    other_org  = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    sign_in_as(other_user)

    post training_session_block_completions_path(@session), params: { block_index: "0" }

    assert_response :not_found
    assert_equal [], @session.reload.progress
  end

  test "destroy unmarks the block and redirects back" do
    @session.update!(progress: [ "0", "1" ])
    sign_in_as(@user)

    delete training_session_block_completion_path(@session, "0")

    assert_redirected_to training_sessions_path
    assert_equal [ "1" ], @session.reload.progress
  end

  test "destroy is idempotent for an unmarked index" do
    sign_in_as(@user)

    delete training_session_block_completion_path(@session, "2")

    assert_redirected_to training_sessions_path
    assert_equal [], @session.reload.progress
  end

  test "destroy rejects an out-of-range block_index with a flash alert" do
    sign_in_as(@user)

    delete training_session_block_completion_path(@session, "99")

    assert_redirected_to training_sessions_path
    follow_redirect!
    assert_match(/bloco/i, flash[:alert] || "")
  end

  test "destroy allows another trainer in the same organization to unmark a block" do
    @session.update!(progress: [ "0" ])
    other = users(:two)
    sign_in_as(other)

    delete training_session_block_completion_path(@session, "0")

    assert_redirected_to training_sessions_path
    assert_equal [], @session.reload.progress
  end

  test "destroy rejects a trainer from a different organization with 404" do
    @session.update!(progress: [ "0" ])
    other_org  = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    sign_in_as(other_user)

    delete training_session_block_completion_path(@session, "0")

    assert_response :not_found
    assert_equal [ "0" ], @session.reload.progress
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

    def three_exercise_blocks
      [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "3x10" },
        { "kind" => "exercise", "name" => "Supino",      "prescription" => "3x8" },
        { "kind" => "exercise", "name" => "Remada",      "prescription" => "3x12" }
      ]
    end
end
