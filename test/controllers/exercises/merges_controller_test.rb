require "test_helper"

class Exercises::MergesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "create requires authentication" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino reto com barra")

    post exercise_merges_path(loser), params: { target_id: survivor.id }

    assert_redirected_to new_session_path
    assert_nil loser.reload.merged_into
  end

  test "create merges the exercise into the chosen target and redirects to the survivor" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino reto com barra")

    sign_in_as(@user)
    post exercise_merges_path(loser), params: { target_id: survivor.id }

    assert_redirected_to exercise_path(survivor)
    assert_equal survivor, loser.reload.merged_into
    assert_equal survivor, Exercise.resolve("Supino reto com barra")
  end

  test "create rejects a blank or unknown target" do
    loser = Exercise.create!(name: "Supino reto com barra")

    sign_in_as(@user)
    post exercise_merges_path(loser), params: { target_id: "" }

    assert_redirected_to exercise_path(loser)
    assert_nil loser.reload.merged_into
  end

  test "create refuses to merge an exercise into itself" do
    exercise = Exercise.create!(name: "Supino reto")

    sign_in_as(@user)
    post exercise_merges_path(exercise), params: { target_id: exercise.id }

    assert_redirected_to exercise_path(exercise)
    assert_nil exercise.reload.merged_into
  end

  test "create cannot target an already-merged exercise" do
    survivor = Exercise.create!(name: "Supino reto")
    merged = Exercise.create!(name: "Supino reto com barra")
    merged.merge_into!(survivor)
    loser = Exercise.create!(name: "Supino na barra")

    sign_in_as(@user)
    post exercise_merges_path(loser), params: { target_id: merged.id }

    assert_redirected_to exercise_path(loser)
    assert_nil loser.reload.merged_into
  end
end
