require "test_helper"

class Student::MedalsViewTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @current_week = Time.zone.today.beginning_of_week
  end

  test "weekly_streak reports the current streak and best-ever streak distinctly" do
    @student.update!(weekly_frequency: 2)
    # Two Full weeks, then two consecutive misses: best 2, current 0.
    fill_week(weeks_ago: 4)
    fill_week(weeks_ago: 3)
    @student.evaluate_medals!

    family = payload_for("weekly_streak")
    assert_not family[:locked]
    assert_equal 0, family[:current_value], "Atual shows the current streak"
    assert_equal 2, family[:best_value], "Recorde shows the best-ever streak"
    assert_equal 2, family[:highest_tier]
  end

  test "weekly families render locked with a nil current value when no cadence is set" do
    fill_week(weeks_ago: 1, count: 5) # ignored without a cadence
    @student.evaluate_medals!

    family = payload_for("weekly_streak")
    assert family[:locked]
    assert_nil family[:current_value]
  end

  private
    def payload_for(key)
      Student::MedalsView.new(@student).to_h[:families].find { |family| family[:key] == key }
    end

    def fill_week(weeks_ago:, count: 2)
      timestamp = (@current_week - weeks_ago.weeks).in_time_zone + 2.days
      count.times do
        @student.training_sessions.create!(
          workout_name_snapshot: "Treino", workout_position_snapshot: 1,
          blocks_snapshot: [], progress: [], created_at: timestamp, finished_at: timestamp
        )
      end
    end
end
