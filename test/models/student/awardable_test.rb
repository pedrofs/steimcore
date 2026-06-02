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

  test "cadence-dependent families have no metric yet and stay unearned" do
    finish_sessions(5)

    @student.evaluate_medals!

    assert_empty earned_tiers("weekly_streak")
    assert_empty earned_tiers("full_weeks")
    assert_empty earned_tiers("periodizations")
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

    def earned_tiers(family)
      @student.student_medals.where(family: family).order(:tier).pluck(:tier)
    end
end
