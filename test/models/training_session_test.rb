require "test_helper"

class TrainingSessionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "requires student and snapshot fields" do
    session = TrainingSession.new

    assert_not session.valid?
    assert_includes session.errors[:student], "must exist"
    assert_includes session.errors[:workout_name_snapshot], "can't be blank"
    assert_includes session.errors[:workout_position_snapshot], "can't be blank"
  end

  test "trainer is optional (student-initiated sessions have no trainer)" do
    session = build_valid_session(trainer: nil)

    assert session.valid?, session.errors.full_messages.inspect
    assert_empty session.errors[:trainer]
  end

  test "workout is optional" do
    session = build_valid_session(workout: nil)

    assert session.valid?, session.errors.full_messages.inspect
  end

  test "validates blocks_snapshot via Workout::Blocks.errors_for" do
    session = build_valid_session(blocks_snapshot: [ { "kind" => "exercise" } ])

    assert_not session.valid?
    assert_match(/bloco 0: name ausente/, session.errors[:blocks_snapshot].join)
  end

  test "valid with empty blocks_snapshot" do
    session = build_valid_session(blocks_snapshot: [])
    assert session.valid?, session.errors.full_messages.inspect
  end

  test "defaults progress to an empty array" do
    session = TrainingSession.new
    assert_equal [], session.progress
  end

  test "defaults blocks_snapshot to an empty array" do
    session = TrainingSession.new
    assert_equal [], session.blocks_snapshot
  end

  test "User has_many :training_sessions through trainer_id" do
    session = build_valid_session
    session.save!

    assert_includes @trainer.training_sessions, session
  end

  test "Student has_many :training_sessions" do
    session = build_valid_session
    session.save!

    assert_includes @student.training_sessions, session
  end

  test "Workout has_many :training_sessions with dependent: :nullify" do
    workout = create_workout
    session = build_valid_session(workout: workout)
    session.save!

    assert_includes workout.training_sessions, session

    workout.destroy!

    assert_nil session.reload.workout_id
  end

  test "partial unique index forbids two active sessions for the same student" do
    build_valid_session.save!

    duplicate = build_valid_session

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "partial unique index allows a new active session after the previous one is finished" do
    first = build_valid_session
    first.save!
    first.update!(finished_at: Time.current)

    second = build_valid_session
    assert_nothing_raised { second.save! }
  end

  test "finishing a session enqueues medal evaluation for the student" do
    session = build_valid_session
    session.save!

    assert_enqueued_with(job: MedalEvaluationJob, args: [ @student ]) do
      session.finish!
    end
  end

  test "creating an already-finished (backdated) session enqueues medal evaluation" do
    assert_enqueued_with(job: MedalEvaluationJob, args: [ @student ]) do
      build_valid_session(finished_at: Time.current).save!
    end
  end

  test "reopening a finished session does not enqueue medal evaluation" do
    session = build_valid_session(finished_at: Time.current)
    session.save!

    assert_no_enqueued_jobs only: MedalEvaluationJob do
      session.reopen!
    end
  end

  test "claim! assigns the trainer to a student-started session" do
    session = build_valid_session(trainer: nil)
    session.save!

    session.claim!(trainer: @trainer)

    assert_equal @trainer.id, session.reload.trainer_id
  end

  test "claim! does not enqueue medal evaluation" do
    session = build_valid_session(trainer: nil)
    session.save!

    assert_no_enqueued_jobs only: MedalEvaluationJob do
      session.claim!(trainer: @trainer)
    end
  end

  private
    def build_valid_session(**overrides)
      defaults = {
        student: @student,
        trainer: @trainer,
        workout_name_snapshot: "Treino A",
        workout_position_snapshot: 1,
        blocks_snapshot: [],
        progress: []
      }
      TrainingSession.new(defaults.merge(overrides))
    end

    def create_workout
      version = @student.start_periodization!(trainer: @trainer)
      version.workouts.create!(name: "Treino A", position: 1, blocks: [])
    end
end
