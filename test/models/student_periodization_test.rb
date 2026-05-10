require "test_helper"

# Focuses on the periodization-flow methods on Student. The base Student
# behaviour lives in test/models/student_test.rb.
class StudentPeriodizationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @trainer,
      kind: "periodization_create"
    )
  end

  test "start_periodization! creates a new periodization with a generating version and repoints the student" do
    assert_nil @student.active_periodization_id

    version = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)

    @student.reload
    assert_equal version.periodization_id, @student.active_periodization_id
    assert_equal "generating", version.status
    assert_equal @trainer, version.trainer
    assert_equal @recording, version.voice_recording
    assert_nil version.parent_version_id
  end

  test "Periodization#start_edit! with :workout creates a pending generating version pointing at the parent" do
    parent_version = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)
    parent_version.fork_with!(
      scope: :create,
      patch: {
        body_md: "x",
        workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "X", prescription: "3x5" } ], position: 1 } ]
      },
      trainer: @trainer,
      voice_recording: @recording
    )
    parent_version.transition_to!(:completed)
    periodization = parent_version.periodization
    periodization.set_current_version!(parent_version)
    target = parent_version.workouts.first

    edit_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_workout", target_workout: target
    )

    new_version = periodization.start_edit!(
      scope: :workout,
      trainer: @trainer,
      voice_recording: edit_recording,
      target_workout: target
    )

    assert_equal "generating", new_version.status
    assert_equal parent_version.id, new_version.parent_version_id
    assert_equal edit_recording, new_version.voice_recording
    assert_equal periodization.id, new_version.periodization_id
    assert_equal parent_version.id, periodization.reload.current_version_id, "current_version is unchanged until promotion"
  end

  test "Periodization#start_edit! with :periodization creates a pending generating version pointing at the parent (no target_workout required)" do
    parent_version = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)
    parent_version.fork_with!(
      scope: :create,
      patch: { body_md: "x", workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "X", prescription: "3x5" } ], position: 1 } ] },
      trainer: @trainer,
      voice_recording: @recording
    )
    parent_version.transition_to!(:completed)
    periodization = parent_version.periodization
    periodization.set_current_version!(parent_version)

    edit_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_periodization"
    )

    new_version = periodization.start_edit!(
      scope: :periodization,
      trainer: @trainer,
      voice_recording: edit_recording
    )

    assert_equal "generating", new_version.status
    assert_equal parent_version.id, new_version.parent_version_id
    assert_equal edit_recording, new_version.voice_recording
    assert_equal periodization.id, new_version.periodization_id
    assert_equal parent_version.id, periodization.reload.current_version_id, "current_version is unchanged until promotion"
  end

  test "Periodization#start_edit! rejects unknown scopes and missing target_workout" do
    parent_version = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)
    parent_version.fork_with!(
      scope: :create,
      patch: { body_md: "x", workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "X", prescription: "3x5" } ], position: 1 } ] },
      trainer: @trainer,
      voice_recording: @recording
    )
    parent_version.transition_to!(:completed)
    periodization = parent_version.periodization
    periodization.set_current_version!(parent_version)

    assert_raises(ArgumentError) do
      periodization.start_edit!(scope: :workout, trainer: @trainer, voice_recording: @recording, target_workout: nil)
    end

    assert_raises(ArgumentError) do
      periodization.start_edit!(scope: :bogus, trainer: @trainer, voice_recording: @recording, target_workout: parent_version.workouts.first)
    end
  end

  test "start_periodization! archives the prior active periodization in the same transaction" do
    first = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)
    first_periodization = first.periodization
    assert_not first_periodization.archived?

    second_recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @trainer,
      kind: "periodization_create"
    )

    second = @student.start_periodization!(trainer: @trainer, voice_recording: second_recording)

    assert first_periodization.reload.archived?
    assert_not second.periodization.reload.archived?
    assert_equal second.periodization_id, @student.reload.active_periodization_id
    assert_not_equal first.periodization_id, second.periodization_id
  end
end
