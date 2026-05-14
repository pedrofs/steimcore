require "test_helper"

class TrainingSession::SwappableTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @alice = students(:alice)
    @trainer = users(:one)
  end

  test "swap_workout! rewrites name, position, and blocks snapshots and resets progress" do
    workouts = make_eligible(@alice, workout_count: 2)
    session = create_session(@alice, workout: workouts[0], progress: [ "0" ])

    session.swap_workout!(workouts[1])

    session.reload
    assert_equal workouts[1].id, session.workout_id
    assert_equal workouts[1].name, session.workout_name_snapshot
    assert_equal workouts[1].position, session.workout_position_snapshot
    assert_equal workouts[1].blocks, session.blocks_snapshot
    assert_equal [], session.progress
  end

  test "swap_workout! is a no-op when progress is empty (still rewrites snapshot fields)" do
    workouts = make_eligible(@alice, workout_count: 2)
    session = create_session(@alice, workout: workouts[0], progress: [])

    session.swap_workout!(workouts[1])

    session.reload
    assert_equal workouts[1].id, session.workout_id
    assert_equal [], session.progress
  end

  test "swap_workout! raises ArgumentError when target belongs to a different periodization version" do
    own_workouts = make_eligible(@alice, workout_count: 1)
    session = create_session(@alice, workout: own_workouts[0])

    other_student = students(:bob)
    other_workouts = make_eligible(other_student, workout_count: 1)

    assert_raises(ArgumentError) { session.swap_workout!(other_workouts[0]) }
  end

  test "swap_workout! rollback leaves all fields unchanged when target is invalid" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = create_session(@alice, workout: workouts[0], progress: [ "0" ])
    original_attrs = session.slice(:workout_id, :workout_name_snapshot, :workout_position_snapshot, :blocks_snapshot, :progress)

    other_student = students(:bob)
    other_workouts = make_eligible(other_student, workout_count: 1)

    assert_raises(ArgumentError) { session.swap_workout!(other_workouts[0]) }

    session.reload
    assert_equal original_attrs["workout_id"], session.workout_id
    assert_equal original_attrs["workout_name_snapshot"], session.workout_name_snapshot
    assert_equal original_attrs["workout_position_snapshot"], session.workout_position_snapshot
    assert_equal original_attrs["blocks_snapshot"], session.blocks_snapshot
    assert_equal original_attrs["progress"], session.progress
  end

  test "swap_workout! accepts a workout from student's current periodization version when workout_id is nil (fallback)" do
    workouts = make_eligible(@alice, workout_count: 2)
    session = create_session(@alice, workout: workouts[0])
    session.update_columns(workout_id: nil)

    session.swap_workout!(workouts[1])

    session.reload
    assert_equal workouts[1].id, session.workout_id
    assert_equal workouts[1].name, session.workout_name_snapshot
  end

  test "swap_workout! fallback rejects workouts that don't belong to student's current periodization version" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = create_session(@alice, workout: workouts[0])
    session.update_columns(workout_id: nil)

    other_student = students(:bob)
    other_workouts = make_eligible(other_student, workout_count: 1)

    assert_raises(ArgumentError) { session.swap_workout!(other_workouts[0]) }
  end

  test "swap_workout! to the same workout is allowed and resets progress" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = create_session(@alice, workout: workouts[0], progress: [ "0" ])

    session.swap_workout!(workouts[0])

    session.reload
    assert_equal workouts[0].id, session.workout_id
    assert_equal [], session.progress
  end

  private
    def make_eligible(student, workout_count:)
      version = student.start_periodization!(trainer: @trainer)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(
          name: "Treino #{i + 1}",
          position: i + 1,
          blocks: [ { "kind" => "exercise", "name" => "Ex #{i + 1}", "prescription" => "3x10" } ]
        )
      end
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end

    def create_session(student, workout:, progress: [])
      TrainingSession.create!(
        student: student,
        trainer: @trainer,
        workout: workout,
        workout_name_snapshot: workout.name,
        workout_position_snapshot: workout.position,
        blocks_snapshot: workout.blocks,
        progress: progress
      )
    end
end
