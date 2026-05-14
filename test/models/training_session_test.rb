require "test_helper"

class TrainingSessionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "requires student, trainer, and snapshot fields" do
    session = TrainingSession.new

    assert_not session.valid?
    assert_includes session.errors[:student], "must exist"
    assert_includes session.errors[:trainer], "must exist"
    assert_includes session.errors[:workout_name_snapshot], "can't be blank"
    assert_includes session.errors[:workout_position_snapshot], "can't be blank"
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
