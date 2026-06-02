require "test_helper"

class MedalTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
  end

  test "registers the four families with their pt-BR names" do
    assert_equal %w[workouts weekly_streak full_weeks periodizations], Medal.families.map(&:key)
    assert_equal "Treinos", Medal.find("workouts").name
  end

  test "workouts metric counts finished training sessions" do
    @student.training_sessions.create!(
      workout_name_snapshot: "Treino", workout_position_snapshot: 1,
      blocks_snapshot: [], progress: [], finished_at: Time.current
    )
    @student.training_sessions.create!(
      workout_name_snapshot: "Treino", workout_position_snapshot: 2,
      blocks_snapshot: [], progress: []
    )

    assert_equal 1, Medal.find("workouts").metric(@student)
  end

  test "cadence-dependent families have no metric yet" do
    %w[weekly_streak full_weeks periodizations].each do |key|
      assert_nil Medal.find(key).metric(@student), "#{key} should not have a working metric in this slice"
    end
  end

  test "highest_reached_tier returns the top tier at or below the value" do
    workouts = Medal.find("workouts")

    assert_nil workouts.highest_reached_tier(0)
    assert_equal 1, workouts.highest_reached_tier(4)
    assert_equal 5, workouts.highest_reached_tier(14)
    assert_equal 250, workouts.highest_reached_tier(999)
  end
end
