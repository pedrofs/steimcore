require "test_helper"

class TrainingSession::StartForTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @alice = students(:alice)
    @bob = students(:bob)
    @trainer = users(:one)
  end

  # ---------- next_workout_for ----------

  test "next_workout_for returns the first workout when there is no prior finished session" do
    workouts = make_eligible(@alice, workout_count: 3)

    assert_equal workouts.first.id, TrainingSession.next_workout_for(@alice).id
  end

  test "next_workout_for returns the workout at position+1 when there is a prior finished session" do
    workouts = make_eligible(@alice, workout_count: 3)

    create_finished_session(@alice, workout: workouts[0])

    assert_equal workouts[1].id, TrainingSession.next_workout_for(@alice).id
  end

  test "next_workout_for wraps to the first workout when the prior session was at the last position" do
    workouts = make_eligible(@alice, workout_count: 3)

    create_finished_session(@alice, workout: workouts.last)

    assert_equal workouts.first.id, TrainingSession.next_workout_for(@alice).id
  end

  test "next_workout_for returns nil when student has no active periodization" do
    assert_nil TrainingSession.next_workout_for(@alice)
  end

  # ---------- start_for! ----------

  test "start_for! snapshots name, position, and blocks and assigns associations" do
    workout = make_eligible(@alice, workout_count: 1, blocks: sample_blocks).first

    session = @trainer.training_sessions.start_for!(@alice)

    assert_equal @alice.id, session.student_id
    assert_equal @trainer.id, session.trainer_id
    assert_equal workout.id, session.workout_id
    assert_equal workout.name, session.workout_name_snapshot
    assert_equal workout.position, session.workout_position_snapshot
    assert_equal workout.blocks, session.blocks_snapshot
    assert_nil session.finished_at
  end

  test "start_for! raises when student has no active periodization" do
    error = assert_raises(RuntimeError) { @trainer.training_sessions.start_for!(@alice) }
    assert_match(/periodiza/i, error.message)
  end

  test "start_for! raises when current version is not completed" do
    workout = make_eligible(@alice, workout_count: 1).first
    @alice.active_periodization.current_version.update_columns(status: "generating")

    error = assert_raises(RuntimeError) { @trainer.training_sessions.start_for!(@alice) }
    assert_match(/period/i, error.message)
    assert_no_difference -> { TrainingSession.count } do
      assert_nil TrainingSession.where(student_id: @alice.id, workout_id: workout.id).first
    end
  end

  test "start_for! raises when periodization has no workouts" do
    make_eligible(@alice, workout_count: 0)

    error = assert_raises(RuntimeError) { @trainer.training_sessions.start_for!(@alice) }
    assert_match(/treino/i, error.message)
  end

  test "start_for! raises RecordNotUnique when student already has an active session" do
    make_eligible(@alice, workout_count: 1)
    @trainer.training_sessions.start_for!(@alice)

    assert_raises(ActiveRecord::RecordNotUnique) { @trainer.training_sessions.start_for!(@alice) }
  end

  test "DB partial unique index blocks a second active session for the same student" do
    make_eligible(@alice, workout_count: 1)
    @trainer.training_sessions.start_for!(@alice)

    raw_attrs = {
      student: @alice,
      trainer: @trainer,
      workout_name_snapshot: "X",
      workout_position_snapshot: 1,
      blocks_snapshot: [],
      progress: []
    }
    assert_raises(ActiveRecord::RecordNotUnique) do
      TrainingSession.new(raw_attrs).save!(validate: false)
    end
  end

  test "start_for! auto-picks the next workout based on the latest finished session" do
    workouts = make_eligible(@alice, workout_count: 3)
    create_finished_session(@alice, workout: workouts[0])

    session = @trainer.training_sessions.start_for!(@alice)

    assert_equal workouts[1].id, session.workout_id
    assert_equal workouts[1].position, session.workout_position_snapshot
  end

  private
    def sample_blocks
      [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x10" }
      ]
    end

    def make_eligible(student, workout_count:, blocks: [])
      voice_recording = VoiceRecording.create!(
        organization: @organization, student: student, trainer: @trainer,
        kind: "periodization_create"
      )
      voice_recording.transition_to!(:transcribing)
      voice_recording.update!(transcript: "x")
      voice_recording.transition_to!(:transcribed)
      voice_recording.transition_to!(:generating)

      version = student.start_periodization!(trainer: @trainer, voice_recording: voice_recording)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: blocks)
      end
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
