require "test_helper"

class TrainingSession::WorkoutRevisableTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @alice = students(:alice)
    @trainer = users(:one)
  end

  test "revise_workout! promotes a new completed version" do
    workouts = make_eligible(@alice, workout_count: 2)
    session = start_session(@alice, workout: workouts[0])
    previous_version = workouts[0].periodization_version

    new_version = session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)

    assert_not_equal previous_version.id, new_version.id
    assert_equal "completed", new_version.reload.status
    assert_equal new_version.id, @alice.active_periodization.reload.current_version_id
  end

  test "revise_workout! leaves the previous current version superseded and read-only" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    previous_version = workouts[0].periodization_version

    session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)

    previous_version.reload
    assert previous_version.superseded?
    assert previous_version.read_only?
    assert_not previous_version.promoted?
  end

  test "revise_workout! writes the submitted blocks onto the target workout without touching its name or position" do
    workouts = make_eligible(@alice, workout_count: 2)
    session = start_session(@alice, workout: workouts[0])

    new_version = session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)

    target = new_version.workouts.find_by(position: workouts[0].position)
    assert_equal revised_blocks, target.blocks
    assert_equal workouts[0].name, target.name
    assert_equal workouts[0].position, target.position
  end

  test "revise_workout! carries every other workout forward byte-identically" do
    workouts = make_eligible(@alice, workout_count: 3)
    session = start_session(@alice, workout: workouts[0])

    new_version = session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)

    workouts.drop(1).each do |untouched|
      carried = new_version.workouts.find_by(position: untouched.position)
      assert_equal untouched.name, carried.name
      assert_equal untouched.blocks, carried.blocks
      assert_equal untouched.position, carried.position
    end
  end

  test "revise_workout! re-points the session at the new version and its workout" do
    workouts = make_eligible(@alice, workout_count: 2)
    session = start_session(@alice, workout: workouts[0])

    new_version = session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)

    session.reload
    assert_equal new_version.id, session.periodization_version_id
    assert_equal new_version.workouts.find_by(position: workouts[0].position).id, session.workout_id
    assert_equal revised_blocks, session.blocks_snapshot
    assert_not session.detached?
  end

  test "revise_workout! leaves the workout name and position snapshots unchanged" do
    workouts = make_eligible(@alice, workout_count: 2)
    session = start_session(@alice, workout: workouts[0])

    session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)

    session.reload
    assert_equal workouts[0].name, session.workout_name_snapshot
    assert_equal workouts[0].position, session.workout_position_snapshot
  end

  test "revise_workout! remaps progress instead of resetting it" do
    workouts = make_eligible(@alice, workout_count: 1, blocks: three_blocks)
    session = start_session(@alice, workout: workouts[0])
    session.update!(progress: [ "0", "2" ])

    # [A, B, C] becomes [C, A, novo]: A keeps its tick at 1, C keeps its at 0.
    reordered = [ three_blocks[2], three_blocks[0], revised_blocks[0] ]
    session.revise_workout!(blocks: reordered, origin_indices: [ 2, 0, nil ], trainer: @trainer)

    assert_equal [ "0", "1" ], session.reload.progress
  end

  # Linking is enqueued against the new version once the outer transaction has
  # committed, so the job sees the submitted blocks. The version's completion
  # and each carried-forward workout's creation both trigger it — the same
  # redundancy every existing fork path produces, and harmless because the job
  # is idempotent and reads the whole version when it runs.
  test "revise_workout! enqueues linking for the new version after the transaction commits" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])

    new_version = nil
    assert_enqueued_with(job: LinkExercisesJob) do
      new_version = session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)
    end

    assert_enqueued_with(job: LinkExercisesJob, args: [ new_version ])
  end

  test "revise_workout! does not touch the periodization's other sessions" do
    workouts = make_eligible(@alice, workout_count: 2)
    finished = start_session(@alice, workout: workouts[1])
    finished.update!(finished_at: Time.current)
    session = start_session(@alice, workout: workouts[0])

    session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)

    assert_equal workouts[1].id, finished.reload.workout_id
    assert_equal workouts[1].blocks, finished.blocks_snapshot
  end

  test "revise_workout! rejects invalid blocks with pt-BR errors and forks nothing" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    periodization = @alice.active_periodization
    version_count = periodization.versions.count

    error = assert_raises(TrainingSession::WorkoutRevisable::InvalidBlocks) do
      session.revise_workout!(blocks: [ { "kind" => "exercise", "name" => "" } ], origin_indices: [ nil ], trainer: @trainer)
    end

    assert_equal Blocks.errors_for([ { "kind" => "exercise", "name" => "" } ]), error.messages
    assert_equal version_count, periodization.reload.versions.count
    assert_equal workouts[0].periodization_version_id, periodization.current_version_id
  end

  test "revise_workout! refuses a finished session" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    session.update!(finished_at: Time.current)
    version_count = @alice.active_periodization.versions.count

    assert_raises(ArgumentError) do
      session.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)
    end

    assert_equal version_count, @alice.active_periodization.reload.versions.count
  end

  test "revise_workout! refuses a detached session" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    session.update_columns(workout_id: nil)
    version_count = @alice.active_periodization.versions.count

    assert_raises(ArgumentError) do
      session.reload.revise_workout!(blocks: revised_blocks, origin_indices: [ 0 ], trainer: @trainer)
    end

    assert_equal version_count, @alice.active_periodization.reload.versions.count
  end

  test "detached? is true when the workout reference is null" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    session.update_columns(workout_id: nil)

    assert session.reload.detached?
  end

  test "detached? is true when the version reference is null" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    session.update_columns(periodization_version_id: nil)

    assert session.reload.detached?
  end

  test "detached? is true when another version has been promoted in the same periodization" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    periodization = @alice.active_periodization
    newer = periodization.versions.create!(trainer: @trainer, parent_version: periodization.current_version)
    newer.fork_with!(scope: :clone, patch: nil, trainer: @trainer)
    periodization.set_current_version!(newer)

    assert session.reload.detached?
  end

  test "detached? is true when the student's plan has been replaced" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    make_eligible(@alice, workout_count: 1)

    assert session.reload.detached?
  end

  test "detached? is false for a live session on the current version" do
    workouts = make_eligible(@alice, workout_count: 1)

    assert_not start_session(@alice, workout: workouts[0]).detached?
  end

  test "blocks_digest changes with the blocks snapshot and is stable otherwise" do
    workouts = make_eligible(@alice, workout_count: 1)
    session = start_session(@alice, workout: workouts[0])
    digest = session.blocks_digest

    assert_equal digest, session.reload.blocks_digest

    session.update!(blocks_snapshot: revised_blocks)
    assert_not_equal digest, session.blocks_digest
  end

  private
    def revised_blocks
      [ { "kind" => "exercise", "name" => "Hack squat", "prescription" => "4x8", "rest_s" => 90 } ]
    end

    def three_blocks
      [
        { "kind" => "exercise", "name" => "A", "prescription" => "3x10" },
        { "kind" => "exercise", "name" => "B", "prescription" => "3x10" },
        { "kind" => "exercise", "name" => "C", "prescription" => "3x10" }
      ]
    end

    def make_eligible(student, workout_count:, blocks: nil)
      version = student.start_periodization!(trainer: @trainer)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(
          name: "Treino #{i + 1}",
          position: i + 1,
          blocks: blocks || [ { "kind" => "exercise", "name" => "Ex #{i + 1}", "prescription" => "3x10" } ]
        )
      end
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end

    def start_session(student, workout:)
      TrainingSession.start!(student: student, trainer: @trainer, workout: workout)
    end
end
