require "test_helper"

class Student::SelfServeTrainableTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
    build_active_plan!
  end

  test "start_training_session! on a weekday creates a trainer-less active session on the suggested workout" do
    travel_to monday do
      session = @student.start_training_session!

      assert session.persisted?
      assert_nil session.trainer_id, "student-initiated sessions have no trainer"
      assert_nil session.finished_at, "the started session is active"
      assert_equal "Treino A", session.workout_name_snapshot
      assert_equal @student.id, session.student_id
    end
  end

  test "start_training_session! honors an explicit workout" do
    travel_to monday do
      session = @student.start_training_session!(workout: @workout_b)

      assert_equal "Treino B", session.workout_name_snapshot
    end
  end

  test "start_training_session! on Saturday raises and creates nothing" do
    travel_to saturday do
      assert_no_difference -> { @student.training_sessions.count } do
        error = assert_raises(RuntimeError) { @student.start_training_session! }
        assert_match(/descanso/i, error.message)
      end
    end
  end

  test "start_training_session! on Sunday raises and creates nothing" do
    travel_to sunday do
      assert_no_difference -> { @student.training_sessions.count } do
        assert_raises(RuntimeError) { @student.start_training_session! }
      end
    end
  end

  test "finishing then starting again on the same day succeeds (no same-day lockout)" do
    travel_to monday do
      first = @student.start_training_session!
      first.finish!

      second = @student.start_training_session!

      assert second.persisted?
      assert_not_equal first.id, second.id
    end
  end

  test "active_training_session returns the current unfinished session or nil" do
    travel_to monday do
      assert_nil @student.active_training_session

      session = @student.start_training_session!
      assert_equal session, @student.active_training_session

      session.finish!
      assert_nil @student.active_training_session
    end
  end

  test "self_start_allowed_today? is true on a weekday with an eligible plan" do
    travel_to monday do
      assert @student.self_start_allowed_today?
    end
  end

  test "self_start_allowed_today? is false on a weekend" do
    travel_to saturday do
      assert_not @student.self_start_allowed_today?
    end
  end

  test "self_start_allowed_today? is false without an eligible plan" do
    travel_to monday do
      assert_not students(:bob).self_start_allowed_today?
    end
  end

  private
    def monday
      Time.zone.local(2026, 6, 1, 10, 0, 0)
    end

    def saturday
      Time.zone.local(2026, 6, 6, 10, 0, 0)
    end

    def sunday
      Time.zone.local(2026, 6, 7, 10, 0, 0)
    end

    def build_active_plan!
      periodization = @student.periodizations.create!
      version = periodization.versions.create!(
        trainer: @trainer, status: "completed", periodization_length_weeks: 8
      )
      version.workouts.create!(name: "Treino A", position: 1, blocks: [
        { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" }
      ])
      @workout_b = version.workouts.create!(name: "Treino B", position: 2, blocks: [])
      periodization.set_current_version!(version)
      @student.update!(active_periodization: periodization)
    end
end
