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

  test "weekly families have a live metric gated on an explicit cadence" do
    # No cadence -> nil, so the families stay locked (no fallback, ADR-0005).
    assert_nil Medal.find("weekly_streak").metric(@student)
    assert_nil Medal.find("full_weeks").metric(@student)

    @student.update!(weekly_frequency: 1)
    @student.training_sessions.create!(
      workout_name_snapshot: "Treino", workout_position_snapshot: 1,
      blocks_snapshot: [], progress: [], finished_at: Time.current
    )

    assert_equal 1, Medal.find("weekly_streak").metric(@student)
    assert_equal 1, Medal.find("full_weeks").metric(@student)
  end

  test "weekly_streak current_metric tracks the current streak, distinct from the best-ever peak" do
    @student.update!(weekly_frequency: 2)
    current_week = Time.zone.today.beginning_of_week
    # Two Full weeks then two consecutive misses: best 2, current 0.
    [ 4, 3 ].each do |weeks_ago|
      timestamp = (current_week - weeks_ago.weeks).in_time_zone + 2.days
      2.times do
        @student.training_sessions.create!(
          workout_name_snapshot: "Treino", workout_position_snapshot: 1,
          blocks_snapshot: [], progress: [], created_at: timestamp, finished_at: timestamp
        )
      end
    end

    weekly_streak = Medal.find("weekly_streak")
    assert_equal 2, weekly_streak.metric(@student)
    assert_equal 0, weekly_streak.current_metric(@student)
  end

  test "periodizations metric is gated on an explicit cadence (no fallback)" do
    # Covered in depth by Medal::PeriodizationsMetricTest; here we only assert
    # the family stays locked (nil) until an explicit cadence is set.
    assert_nil Medal.find("periodizations").metric(@student)
  end

  test "highest_reached_tier returns the top tier at or below the value" do
    workouts = Medal.find("workouts")

    assert_nil workouts.highest_reached_tier(0)
    assert_equal 1, workouts.highest_reached_tier(4)
    assert_equal 5, workouts.highest_reached_tier(14)
    assert_equal 250, workouts.highest_reached_tier(999)
  end
end
