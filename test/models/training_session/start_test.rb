require "test_helper"

class TrainingSession::StartTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @alice = students(:alice)
    @trainer = users(:one)
  end

  test "start! without a trainer creates a trainer_id-null active session" do
    workout = make_eligible(@alice, workout_count: 1, blocks: sample_blocks).first

    session = TrainingSession.start!(student: @alice)

    assert_nil session.trainer_id
    assert_equal @alice.id, session.student_id
    assert_equal workout.id, session.workout_id
    assert_equal workout.name, session.workout_name_snapshot
    assert_equal workout.position, session.workout_position_snapshot
    assert_equal workout.blocks, session.blocks_snapshot
    assert_nil session.finished_at
  end

  test "start! with a trainer assigns the trainer" do
    make_eligible(@alice, workout_count: 1)

    session = TrainingSession.start!(student: @alice, trainer: @trainer)

    assert_equal @trainer.id, session.trainer_id
  end

  test "start! honors an explicitly passed workout instead of the auto-pick" do
    workouts = make_eligible(@alice, workout_count: 3)

    session = TrainingSession.start!(student: @alice, workout: workouts.last)

    assert_equal workouts.last.id, session.workout_id
    assert_equal workouts.last.position, session.workout_position_snapshot
    assert_equal workouts.last.name, session.workout_name_snapshot
  end

  test "start! defaults the workout to next_workout_for when none is passed" do
    workouts = make_eligible(@alice, workout_count: 3)
    create_finished_session(@alice, workout: workouts[0])

    session = TrainingSession.start!(student: @alice)

    assert_equal workouts[1].id, session.workout_id
  end

  test "start! raises when the student is archived" do
    make_eligible(@alice, workout_count: 1)
    @alice.archive!

    error = assert_raises(RuntimeError) { TrainingSession.start!(student: @alice) }
    assert_match(/arquivad/i, error.message)
  end

  test "start! raises when the student has no active periodization" do
    error = assert_raises(RuntimeError) { TrainingSession.start!(student: @alice) }
    assert_match(/periodiza/i, error.message)
  end

  test "start! raises when the current version is not completed" do
    make_eligible(@alice, workout_count: 1)
    @alice.active_periodization.current_version.update_columns(status: "generating")

    error = assert_raises(RuntimeError) { TrainingSession.start!(student: @alice) }
    assert_match(/period/i, error.message)
  end

  test "start! raises when the periodization has no workouts" do
    make_eligible(@alice, workout_count: 0)

    error = assert_raises(RuntimeError) { TrainingSession.start!(student: @alice) }
    assert_match(/treino/i, error.message)
  end

  test "start! raises RecordNotUnique on a second active session for the same student" do
    make_eligible(@alice, workout_count: 1)
    TrainingSession.start!(student: @alice)

    assert_raises(ActiveRecord::RecordNotUnique) { TrainingSession.start!(student: @alice) }
  end

  private
    def sample_blocks
      [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x10" }
      ]
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

    def create_finished_session(student, workout:)
      session = TrainingSession.create!(
        student: student,
        trainer: @trainer,
        workout: workout,
        workout_name_snapshot: workout.name,
        workout_position_snapshot: workout.position,
        blocks_snapshot: workout.blocks,
        progress: []
      )
      session.update!(finished_at: Time.current)
      session
    end
end
