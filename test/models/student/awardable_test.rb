require "test_helper"

class Student::AwardableTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
  end

  test "awards the workouts tiers crossed by the finished session count" do
    finish_sessions(5)

    created = @student.evaluate_medals!

    assert_equal [ 1, 5 ], earned_tiers("workouts")
    assert_equal [ 1, 5 ], created.map(&:tier).sort
    assert created.all? { |medal| medal.value_snapshot == 5 }
  end

  test "below the first threshold awards nothing" do
    # The workouts ladder starts at 1, so a student with no finished sessions
    # earns no medals.
    assert_empty @student.evaluate_medals!
    assert_empty earned_tiers("workouts")
  end

  test "awards every tier crossed in a single pass" do
    finish_sessions(25)

    @student.evaluate_medals!

    assert_equal [ 1, 5, 15, 25 ], earned_tiers("workouts")
  end

  test "is idempotent — re-running awards nothing new" do
    finish_sessions(5)
    @student.evaluate_medals!

    assert_no_difference -> { @student.student_medals.count } do
      assert_empty @student.evaluate_medals!
    end
  end

  test "never revokes — a lower metric leaves earned medals intact" do
    # Earn tier 5 (and 1), then evaluate again with the live metric back at 1.
    finish_sessions(5)
    @student.evaluate_medals!
    @student.training_sessions.finished.limit(4).destroy_all
    assert_equal 1, @student.training_sessions.finished.count

    @student.evaluate_medals!

    assert_includes earned_tiers("workouts"), 5, "earned tier must survive the metric drop"
  end

  test "weekly families stay locked without an explicit cadence (no fallback)" do
    # alice has no weekly_frequency, so even plenty of finished sessions earn
    # nothing on the cadence-dependent families.
    4.downto(1) { |weeks_ago| fill_week(weeks_ago: weeks_ago, count: 5) }

    @student.evaluate_medals!

    assert_empty earned_tiers("weekly_streak")
    assert_empty earned_tiers("full_weeks")
  end

  test "periodizations has no metric yet and stays unearned" do
    finish_sessions(5)

    @student.evaluate_medals!

    assert_empty earned_tiers("periodizations")
  end

  test "earns weekly_streak and full_weeks against the current cadence" do
    @student.update!(weekly_frequency: 2)
    4.downto(1) { |weeks_ago| fill_week(weeks_ago: weeks_ago) } # four Full weeks

    @student.evaluate_medals!

    assert_equal [ 2, 4 ], earned_tiers("weekly_streak")
    assert_equal [ 1, 2, 4 ], earned_tiers("full_weeks")
  end

  test "lowering the cadence retroactively unlocks medals; raising it never revokes them" do
    @student.update!(weekly_frequency: 4)
    fill_week(weeks_ago: 2, count: 2)
    fill_week(weeks_ago: 1, count: 2)

    @student.evaluate_medals!
    assert_empty earned_tiers("full_weeks"), "cadence of 4 unmet by 2 sessions/week"

    @student.update!(weekly_frequency: 2)
    @student.evaluate_medals!
    assert_equal [ 1, 2 ], earned_tiers("full_weeks"), "lowering the cadence unlocks the past weeks"

    @student.update!(weekly_frequency: 4)
    @student.evaluate_medals!
    assert_equal [ 1, 2 ], earned_tiers("full_weeks"), "raising the cadence keeps the earned medals"
  end

  private
    def finish_sessions(count)
      count.times do
        @student.training_sessions.create!(
          workout_name_snapshot: "Treino",
          workout_position_snapshot: 1,
          blocks_snapshot: [],
          progress: [],
          finished_at: Time.current
        )
      end
    end

    def fill_week(weeks_ago:, count: nil)
      timestamp = (Time.zone.today.beginning_of_week - weeks_ago.weeks).in_time_zone + 2.days
      (count || @student.weekly_frequency).times do
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

    def earned_tiers(family)
      @student.student_medals.where(family: family).order(:tier).pluck(:tier)
    end
end
