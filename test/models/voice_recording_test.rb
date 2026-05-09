require "test_helper"

class VoiceRecordingTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "requires kind, organization, student, and trainer" do
    recording = VoiceRecording.new

    assert_not recording.valid?
    assert_includes recording.errors[:organization], "must exist"
    assert_includes recording.errors[:student], "must exist"
    assert_includes recording.errors[:trainer], "must exist"
    assert_includes recording.errors[:kind], "can't be blank"
  end

  test "rejects unknown kind" do
    recording = build_recording(kind: "wat")

    assert_not recording.valid?
    assert_includes recording.errors[:kind].join, "is not included"
  end

  test "confirm_transcript! writes the edited transcript and enqueues the next job" do
    recording = build_recording
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "ascii fallback")
    recording.transition_to!(:transcribed)

    assert_enqueued_with(job: RegenerateAnamnesisJob, args: [ recording.id ]) do
      recording.confirm_transcript!("Aluno relatou dor na lombar há 3 meses.")
    end

    recording.reload
    assert_equal "Aluno relatou dor na lombar há 3 meses.", recording.transcript
    assert_not_nil recording.transcript_edited_at
    assert_equal "generating", recording.status
  end

  test "periodization_edit_workout requires a target_workout" do
    recording = VoiceRecording.new(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_workout"
    )

    assert_not recording.valid?
    assert_includes recording.errors[:target_workout], "can't be blank"
  end

  test "confirm_transcript! for periodization_edit_workout starts a pending edit version and enqueues GeneratePeriodizationJob" do
    parent_version = @student.start_periodization!(
      trainer: @trainer,
      voice_recording: VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_create"
      )
    )
    parent_version.fork_with!(
      scope: :create,
      patch: { body_md: "x", workouts: [ { name: "A", content_md: "y", position: 1 } ] },
      trainer: @trainer,
      voice_recording: parent_version.voice_recording
    )
    parent_version.transition_to!(:completed)
    parent_version.periodization.set_current_version!(parent_version)
    target = parent_version.workouts.first

    edit = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_workout", target_workout: target
    )
    edit.transition_to!(:transcribing)
    edit.update!(transcript: "tweak")
    edit.transition_to!(:transcribed)

    assert_difference "PeriodizationVersion.count", 1 do
      assert_enqueued_jobs 1, only: GeneratePeriodizationJob do
        edit.confirm_transcript!("Trocar supino por supino inclinado.")
      end
    end

    new_version = PeriodizationVersion.find_by!(voice_recording_id: edit.id)
    assert_equal "generating", new_version.status
    assert_equal parent_version.id, new_version.parent_version_id
    assert_equal "Trocar supino por supino inclinado.", edit.reload.transcript
  end

  test "confirm_transcript! for periodization_edit_periodization starts a pending edit version and enqueues GeneratePeriodizationJob" do
    parent_version = @student.start_periodization!(
      trainer: @trainer,
      voice_recording: VoiceRecording.create!(
        organization: @organization, student: @student, trainer: @trainer,
        kind: "periodization_create"
      )
    )
    parent_version.fork_with!(
      scope: :create,
      patch: { body_md: "x", workouts: [ { name: "A", content_md: "y", position: 1 } ] },
      trainer: @trainer,
      voice_recording: parent_version.voice_recording
    )
    parent_version.transition_to!(:completed)
    parent_version.periodization.set_current_version!(parent_version)

    edit = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_periodization"
    )
    edit.transition_to!(:transcribing)
    edit.update!(transcript: "tweak")
    edit.transition_to!(:transcribed)

    assert_difference "PeriodizationVersion.count", 1 do
      assert_enqueued_jobs 1, only: GeneratePeriodizationJob do
        edit.confirm_transcript!("Reescrever a periodização inteira focando em força.")
      end
    end

    new_version = PeriodizationVersion.find_by!(voice_recording_id: edit.id)
    assert_equal "generating", new_version.status
    assert_equal parent_version.id, new_version.parent_version_id
    assert_equal parent_version.periodization_id, new_version.periodization_id
    assert_equal "Reescrever a periodização inteira focando em força.", edit.reload.transcript
  end

  test "fail! moves to :failed with error_message" do
    recording = build_recording
    recording.transition_to!(:transcribing)

    recording.fail!("Whisper indisponível")

    recording.reload
    assert_equal "failed", recording.status
    assert_equal "Whisper indisponível", recording.error_message
  end

  test "purge_audio_older_than purges only recordings older than the cutoff with audio attached, leaving transcripts intact" do
    old_with_audio = build_recording
    old_with_audio.audio.attach(io: StringIO.new("old"), filename: "old.webm", content_type: "audio/webm")
    old_with_audio.update!(transcript: "transcrição antiga")
    old_with_audio.update_columns(created_at: 8.days.ago)

    new_with_audio = build_recording
    new_with_audio.audio.attach(io: StringIO.new("new"), filename: "new.webm", content_type: "audio/webm")
    new_with_audio.update!(transcript: "transcrição recente")
    new_with_audio.update_columns(created_at: 1.day.ago)

    old_without_audio = build_recording
    old_without_audio.update!(transcript: "sem áudio")
    old_without_audio.update_columns(created_at: 10.days.ago)

    perform_enqueued_jobs do
      assert_nothing_raised do
        VoiceRecording.purge_audio_older_than(7.days)
      end
    end

    assert_not old_with_audio.reload.audio.attached?, "old recording's audio should have been purged"
    assert new_with_audio.reload.audio.attached?, "recent recording's audio should remain attached"
    assert_not old_without_audio.reload.audio.attached?, "recording without audio should remain detached (no error)"

    assert_equal "transcrição antiga", old_with_audio.transcript
    assert_equal "transcrição recente", new_with_audio.transcript
    assert_equal "sem áudio", old_without_audio.transcript
  end

  private
    def build_recording(**overrides)
      VoiceRecording.create!(
        organization: @organization,
        student: @student,
        trainer: @trainer,
        kind: "anamnesis",
        **overrides
      )
    rescue ActiveRecord::RecordInvalid
      VoiceRecording.new(
        organization: @organization,
        student: @student,
        trainer: @trainer,
        kind: "anamnesis",
        **overrides
      )
    end
end
