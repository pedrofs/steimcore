require "test_helper"

class Student::WeeklyHistoryTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @student.update!(weekly_frequency: 2)
    @current_week = Time.zone.today.beginning_of_week
  end

  test "no cadence returns an empty series and zero aggregates" do
    @student.update!(weekly_frequency: nil)
    history = Student::WeeklyHistory.new(@student)

    assert_not history.cadence?
    assert_equal 0, history.best_streak
    assert_equal 0, history.current_streak
    assert_equal 0, history.full_weeks_count
  end

  test "a single isolated missed week is absorbed by the freeze" do
    fill_week(weeks_ago: 4) # Full
    fill_week(weeks_ago: 3) # Full
    # weeks_ago 2 -> missed (no sessions)
    fill_week(weeks_ago: 1) # Full

    history = Student::WeeklyHistory.new(@student)

    assert_equal 3, history.best_streak
    assert_equal 3, history.current_streak
    assert_equal 3, history.full_weeks_count
  end

  test "two consecutive missed weeks break the streak" do
    fill_week(weeks_ago: 5) # Full
    fill_week(weeks_ago: 4) # Full
    # weeks_ago 3 and 2 -> two consecutive misses
    fill_week(weeks_ago: 1) # Full

    history = Student::WeeklyHistory.new(@student)

    assert_equal 2, history.best_streak
    assert_equal 1, history.current_streak
    assert_equal 3, history.full_weeks_count
  end

  test "the current in-progress week is pending — neither a miss nor counted until it crosses" do
    fill_week(weeks_ago: 1) # Full
    add_sessions(weeks_ago: 0, count: 1) # current week, below cadence -> pending

    history = Student::WeeklyHistory.new(@student)

    assert_equal 1, history.best_streak
    assert_equal 1, history.current_streak
    assert_equal 1, history.full_weeks_count
  end

  test "the current week counts as Full the moment it crosses the threshold" do
    fill_week(weeks_ago: 1) # Full
    fill_week(weeks_ago: 0) # current week reaches the cadence -> Full

    history = Student::WeeklyHistory.new(@student)

    assert_equal 2, history.best_streak
    assert_equal 2, history.current_streak
    assert_equal 2, history.full_weeks_count
  end

  test "a backdated session fills its own past week" do
    add_sessions(weeks_ago: 3, count: 2) # Full purely from backdated sessions

    history = Student::WeeklyHistory.new(@student)

    assert_equal 1, history.full_weeks_count
    assert_equal 1, history.best_streak
  end

  test "raising the cadence shrinks Full weeks; lowering it grows them" do
    add_sessions(weeks_ago: 2, count: 2)
    add_sessions(weeks_ago: 1, count: 2)

    @student.update!(weekly_frequency: 2)
    assert_equal 2, Student::WeeklyHistory.new(@student).full_weeks_count

    @student.update!(weekly_frequency: 3)
    assert_equal 0, Student::WeeklyHistory.new(@student).full_weeks_count
  end

  private
    def fill_week(weeks_ago:)
      add_sessions(weeks_ago: weeks_ago, count: @student.weekly_frequency)
    end

    def add_sessions(weeks_ago:, count:)
      timestamp = (@current_week - weeks_ago.weeks).in_time_zone + 2.days
      count.times do
        @student.training_sessions.create!(
          workout_name_snapshot: "Treino",
          workout_position_snapshot: 1,
          blocks_snapshot: [],
          progress: [],
          created_at: timestamp,
          finished_at: timestamp
        )
      end
    end
end
