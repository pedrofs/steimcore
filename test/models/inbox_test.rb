require "test_helper"

class InboxTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @trainer = users(:one)
    @other_trainer = users(:two)
    @student = students(:alice)
  end

  test "groups are empty when the trainer has no recordings" do
    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [], groups[:failed]
    assert_equal [], groups[:ready]
    assert_equal [], groups[:in_flight]
  end

  test "scopes to the given trainer (does not show other trainers' work)" do
    other_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @other_trainer,
      kind: "anamnesis"
    )
    other_recording.transition_to!(:transcribing)

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [], groups[:in_flight]
    refute_includes groups[:in_flight].map(&:voice_recording_id), other_recording.id
  end

  test "classifies failed-not-dismissed recordings into the failed group" do
    failed = build_failed_anamnesis_recording

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [ failed.id ], groups[:failed].map(&:voice_recording_id)
    assert_equal [], groups[:ready]
    assert_equal [], groups[:in_flight]
  end

  test "hides failed-dismissed recordings from all groups" do
    failed = build_failed_anamnesis_recording
    failed.update!(dismissed_at: Time.current)

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [], groups[:failed]
    assert_equal [], groups[:ready]
    assert_equal [], groups[:in_flight]
  end

  test "classifies completed anamnesis with proposed_anamnesis_md present as ready" do
    recording = build_completed_anamnesis_recording(proposed: "## Proposta")

    groups = Inbox.new(trainer: @trainer).groups

    row = groups[:ready].first
    assert_equal recording.id, row.voice_recording_id
    assert_equal "anamnesis", row.kind
    assert_equal "/students/#{@student.id}/voice_recordings/#{recording.id}", row.url
  end

  test "hides completed anamnesis with blank proposed_anamnesis_md (treated as already acted on)" do
    recording = build_completed_anamnesis_recording(proposed: nil)

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [], groups[:ready]
  end

  test "classifies completed periodization_create with unpromoted version as ready" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Quero três treinos.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    version = @student.start_periodization!(trainer: @trainer, voice_recording: recording)
    version.complete!

    groups = Inbox.new(trainer: @trainer).groups

    row = groups[:ready].first
    assert_equal recording.id, row.voice_recording_id
    assert_equal "/periodization_versions/#{version.id}", row.url
  end

  test "hides completed periodization_create with promoted version" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Quero três treinos.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    version = @student.start_periodization!(trainer: @trainer, voice_recording: recording)
    version.complete!
    version.periodization.set_current_version!(version)

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [], groups[:ready]
  end

  test "classifies pending, transcribing, and generating recordings as in_flight" do
    pending = build_recording(kind: "anamnesis")
    transcribing = build_recording(kind: "anamnesis")
    transcribing.transition_to!(:transcribing)
    generating = build_recording(kind: "anamnesis")
    generating.transition_to!(:transcribing)
    generating.update!(transcript: "x")
    generating.transition_to!(:transcribed)
    generating.transition_to!(:generating)

    groups = Inbox.new(trainer: @trainer).groups

    in_flight_ids = groups[:in_flight].map(&:voice_recording_id)
    assert_includes in_flight_ids, pending.id
    assert_includes in_flight_ids, transcribing.id
    assert_includes in_flight_ids, generating.id
  end

  test "in_flight rows have a null url (not clickable)" do
    recording = build_recording(kind: "anamnesis")
    recording.transition_to!(:transcribing)

    groups = Inbox.new(trainer: @trainer).groups

    assert_nil groups[:in_flight].first.url
  end

  test "failed group is sorted newest first" do
    older = build_failed_anamnesis_recording
    older.update_columns(created_at: 2.hours.ago)
    newer = build_failed_anamnesis_recording

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [ newer.id, older.id ], groups[:failed].map(&:voice_recording_id)
  end

  test "ready group is sorted oldest first (FIFO)" do
    older = build_completed_anamnesis_recording(proposed: "## A")
    older.update_columns(created_at: 2.hours.ago)
    newer = build_completed_anamnesis_recording(proposed: "## B")

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [ older.id, newer.id ], groups[:ready].map(&:voice_recording_id)
  end

  test "in_flight group is sorted newest first" do
    older = build_recording(kind: "anamnesis")
    older.transition_to!(:transcribing)
    older.update_columns(created_at: 2.hours.ago)
    newer = build_recording(kind: "anamnesis")
    newer.transition_to!(:transcribing)

    groups = Inbox.new(trainer: @trainer).groups

    assert_equal [ newer.id, older.id ], groups[:in_flight].map(&:voice_recording_id)
  end

  test "anamnesis row carries student name and a kind label" do
    recording = build_completed_anamnesis_recording(proposed: "## P")

    row = Inbox.new(trainer: @trainer).groups[:ready].first

    assert_equal @student.id, row.student_id
    assert_equal @student.name, row.student_name
    assert_match(/anamnese/i, row.label)
  end

  test "periodization_edit_workout row label includes the target workout name" do
    base_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    base_recording.transition_to!(:transcribing)
    base_recording.update!(transcript: "Cria.")
    base_recording.transition_to!(:transcribed)
    base_recording.transition_to!(:generating)
    base_version = @student.start_periodization!(trainer: @trainer, voice_recording: base_recording)
    base_version.workouts.create!(name: "Treino A", position: 1, blocks: [])
    base_version.complete!
    periodization = base_version.periodization
    periodization.set_current_version!(base_version)
    target_workout = base_version.workouts.first

    edit_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_workout", target_workout: target_workout
    )
    edit_recording.transition_to!(:transcribing)
    edit_recording.update!(transcript: "Troca o supino.")
    edit_recording.transition_to!(:transcribed)
    edit_recording.transition_to!(:generating)
    edit_version = periodization.start_edit!(
      scope: :workout, trainer: @trainer,
      voice_recording: edit_recording, target_workout: target_workout
    )
    edit_version.complete!

    ready_rows = Inbox.new(trainer: @trainer).groups[:ready]
    edit_row = ready_rows.find { |r| r.voice_recording_id == edit_recording.id }

    assert_match(/Treino A/, edit_row.label)
    assert_equal "/periodization_versions/#{edit_version.id}", edit_row.url
  end

  test "failed row carries error message" do
    failed = build_failed_anamnesis_recording

    row = Inbox.new(trainer: @trainer).groups[:failed].first

    assert_equal "Whisper indisponível", row.error_message
  end

  test "in_flight row carries a kind-aware display status" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "x")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)

    row = Inbox.new(trainer: @trainer).groups[:in_flight].first

    assert_match(/periodização/i, row.display_status)
  end

  test "count is zero when the trainer has no recordings" do
    assert_equal 0, Inbox.new(trainer: @trainer).count
  end

  test "count includes failed-not-dismissed recordings" do
    build_failed_anamnesis_recording

    assert_equal 1, Inbox.new(trainer: @trainer).count
  end

  test "count excludes failed-dismissed recordings" do
    failed = build_failed_anamnesis_recording
    failed.update!(dismissed_at: Time.current)

    assert_equal 0, Inbox.new(trainer: @trainer).count
  end

  test "count includes ready (completed + unacted) recordings" do
    build_completed_anamnesis_recording(proposed: "## Proposta")

    assert_equal 1, Inbox.new(trainer: @trainer).count
  end

  test "count excludes in-flight recordings" do
    recording = build_recording(kind: "anamnesis")
    recording.transition_to!(:transcribing)

    assert_equal 0, Inbox.new(trainer: @trainer).count
  end

  test "count is scoped to the given trainer" do
    other_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @other_trainer,
      kind: "anamnesis"
    )
    other_recording.transition_to!(:transcribing)
    other_recording.fail!("nope")

    assert_equal 0, Inbox.new(trainer: @trainer).count
    assert_equal 1, Inbox.new(trainer: @other_trainer).count
  end

  private
    def build_recording(kind:)
      VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: kind
      )
    end

    def build_failed_anamnesis_recording
      recording = build_recording(kind: "anamnesis")
      recording.transition_to!(:transcribing)
      recording.fail!("Whisper indisponível")
      recording
    end

    def build_completed_anamnesis_recording(proposed:)
      recording = build_recording(kind: "anamnesis")
      recording.transition_to!(:transcribing)
      recording.update!(transcript: "Aluno cita dor lombar.")
      recording.transition_to!(:transcribed)
      recording.transition_to!(:generating)
      recording.update!(proposed_anamnesis_md: proposed)
      recording.transition_to!(:completed)
      recording
    end
end
