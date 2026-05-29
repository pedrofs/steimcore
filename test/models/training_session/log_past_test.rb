require "test_helper"

class TrainingSession::LogPastTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @alice = students(:alice)
    @bob = students(:bob)
    @trainer = users(:one)
  end

  test "log_past_for! creates a finished session backdated to on_date with snapshots" do
    workout = make_eligible(@alice, workout_count: 1, blocks: sample_blocks).first
    on_date = Date.current - 2

    session = @trainer.training_sessions.log_past_for!(@alice, on_date: on_date, workout: workout)

    assert_equal @alice.id, session.student_id
    assert_equal @trainer.id, session.trainer_id
    assert_equal workout.id, session.workout_id
    assert_equal workout.name, session.workout_name_snapshot
    assert_equal workout.position, session.workout_position_snapshot
    assert_equal workout.blocks, session.blocks_snapshot
    assert_equal on_date, session.created_at.in_time_zone.to_date
    assert_not_nil session.finished_at
  end

  test "log_past! raises for future dates" do
    workout = make_eligible(@alice, workout_count: 1).first

    error = assert_raises(RuntimeError) do
      @trainer.training_sessions.log_past_for!(@alice, on_date: Date.current + 1, workout: workout)
    end
    assert_match(/futura/i, error.message)
  end

  test "log_past! raises when workout belongs to a different periodization" do
    make_eligible(@alice, workout_count: 1)
    bob_workout = make_eligible(@bob, workout_count: 1).first

    error = assert_raises(RuntimeError) do
      @trainer.training_sessions.log_past_for!(@alice, on_date: Date.current, workout: bob_workout)
    end
    assert_match(/periodiza/i, error.message)
  end

  test "log_past! raises when student has no active periodization" do
    workout = make_eligible(@bob, workout_count: 1).first

    error = assert_raises(RuntimeError) do
      @trainer.training_sessions.log_past_for!(@alice, on_date: Date.current, workout: workout)
    end
    assert_match(/periodiza/i, error.message)
  end

  test "log_past! allows a backdated session even when the student has an active live session" do
    workout = make_eligible(@alice, workout_count: 1).first
    @trainer.training_sessions.start_for!(@alice)

    assert_difference -> { TrainingSession.count }, 1 do
      @trainer.training_sessions.log_past_for!(@alice, on_date: Date.current - 1, workout: workout)
    end
  end

  private
    def sample_blocks
      [ { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x10" } ]
    end

    def make_eligible(student, workout_count:, blocks: [])
      version = student.start_periodization!(trainer: @trainer)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: blocks)
      end
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end
end
