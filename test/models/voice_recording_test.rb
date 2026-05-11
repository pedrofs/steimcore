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

  test "confirm_transcript! is not part of the public surface" do
    recording = build_recording

    assert_not recording.public_methods.include?(:confirm_transcript!),
      "confirm_transcript! must be private (invoked by Transcribable#transcribe!), not a public action"
  end

  test "periodization_edit_workout requires a target_workout" do
    recording = VoiceRecording.new(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_workout"
    )

    assert_not recording.valid?
    assert_includes recording.errors[:target_workout], "can't be blank"
  end

  test "fail! moves to :failed with error_message" do
    recording = build_recording
    recording.transition_to!(:transcribing)

    recording.fail!("Whisper indisponível")

    recording.reload
    assert_equal "failed", recording.status
    assert_equal "Whisper indisponível", recording.error_message
  end

  test "allows the new failed -> generating transition (smart retry under transcript-present failures)" do
    recording = build_recording
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Aluno cita dor lombar.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    recording.fail!("LLM indisponível")

    assert_equal "failed", recording.reload.status
    recording.error_message = nil
    recording.transition_to!(:generating)

    assert_equal "generating", recording.reload.status
  end

  test "retry! on failed recording with blank transcript transitions to :pending and re-enqueues TranscribeJob" do
    recording = build_recording
    recording.transition_to!(:transcribing)
    recording.fail!("Whisper indisponível")

    assert_equal "failed", recording.reload.status
    assert recording.transcript.blank?

    assert_enqueued_with(job: TranscribeJob, args: [ recording ]) do
      recording.retry!
    end

    recording.reload
    assert_equal "pending", recording.status
    assert_nil recording.error_message
  end

  test "retry! on failed anamnesis recording with transcript present transitions to :generating and re-enqueues RegenerateAnamnesisJob" do
    recording = build_recording
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Aluno cita dor lombar.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    recording.fail!("LLM indisponível")

    assert_enqueued_with(job: RegenerateAnamnesisJob, args: [ recording ]) do
      recording.retry!
    end

    recording.reload
    assert_equal "generating", recording.status
    assert_nil recording.error_message
  end

  test "retry! on failed periodization_create recording with transcript present resets associated version and re-enqueues GeneratePeriodizationJob" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Quero ganhar massa muscular.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    version = @student.start_periodization!(trainer: @trainer, voice_recording: recording)
    version.fail!("LLM indisponível")

    assert_equal "failed", recording.reload.status
    assert_equal "failed", version.reload.status

    assert_enqueued_with(job: GeneratePeriodizationJob, args: [ version ]) do
      recording.retry!
    end

    assert_equal "generating", recording.reload.status
    assert_nil recording.error_message
    assert_equal "generating", version.reload.status
    assert_nil version.error_message
  end

  test "retry! on failed periodization_edit_workout recording with transcript present resets version and re-enqueues GeneratePeriodizationJob" do
    create_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    create_recording.transition_to!(:transcribing)
    create_recording.update!(transcript: "Cria.")
    create_recording.transition_to!(:transcribed)
    create_recording.transition_to!(:generating)
    base_version = @student.start_periodization!(trainer: @trainer, voice_recording: create_recording)
    base_version.workouts.create!(name: "A", position: 1, blocks: [])
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
    edit_version.fail!("LLM indisponível")

    assert_enqueued_with(job: GeneratePeriodizationJob, args: [ edit_version ]) do
      edit_recording.retry!
    end

    assert_equal "generating", edit_recording.reload.status
    assert_equal "generating", edit_version.reload.status
  end

  test "retry! on a recording not in :failed is a no-op" do
    recording = build_recording
    assert_equal "pending", recording.status

    assert_no_enqueued_jobs do
      recording.retry!
    end

    assert_equal "pending", recording.reload.status
  end

  test "dismiss! on a failed anamnesis recording sets dismissed_at without touching the student" do
    @student.update!(anamnesis_md: "## Histórico\n\nLesão antiga.")
    recording = build_recording
    recording.transition_to!(:transcribing)
    recording.fail!("Whisper indisponível")

    freeze_time do
      recording.dismiss!

      assert_equal Time.current, recording.reload.dismissed_at
    end

    assert_equal "## Histórico\n\nLesão antiga.", @student.reload.anamnesis_md
  end

  test "dismiss! on a failed periodization_create archives the periodization when no other completed versions exist" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Quero ganhar massa.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    version = @student.start_periodization!(trainer: @trainer, voice_recording: recording)
    version.fail!("LLM indisponível")

    recording.dismiss!

    assert_not_nil recording.reload.dismissed_at
    assert version.reload.periodization.archived?
  end

  test "dismiss! on a failed periodization_create leaves the periodization unarchived when another completed version exists" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    recording.transition_to!(:transcribing)
    recording.update!(transcript: "Quero ganhar massa.")
    recording.transition_to!(:transcribed)
    recording.transition_to!(:generating)
    version = @student.start_periodization!(trainer: @trainer, voice_recording: recording)
    version.complete!
    periodization = version.periodization
    # Force a second failed version on the same periodization to simulate the
    # branch where the dismissed recording is failed but its parent already
    # has a completed sibling — periodization stays alive.
    failed_version = periodization.versions.create!(trainer: @trainer, parent_version: version)
    failed_version.transition_to!(:generating)
    failed_version.fail!("LLM indisponível")
    failed_version_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    failed_version_recording.transition_to!(:transcribing)
    failed_version_recording.fail!("LLM indisponível")
    failed_version.update!(voice_recording: failed_version_recording)

    failed_version_recording.dismiss!

    assert_not_nil failed_version_recording.reload.dismissed_at
    refute periodization.reload.archived?
  end

  test "dismiss! on a failed periodization_edit_workout leaves the parent periodization and current version untouched" do
    base_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    base_recording.transition_to!(:transcribing)
    base_recording.update!(transcript: "Cria.")
    base_recording.transition_to!(:transcribed)
    base_recording.transition_to!(:generating)
    base_version = @student.start_periodization!(trainer: @trainer, voice_recording: base_recording)
    base_version.workouts.create!(name: "A", position: 1, blocks: [])
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
    edit_version.fail!("LLM indisponível")

    edit_recording.dismiss!

    assert_not_nil edit_recording.reload.dismissed_at
    refute periodization.reload.archived?
    assert_equal base_version.id, periodization.current_version_id
  end

  test "dismiss! on a failed periodization_edit_periodization leaves the parent periodization and current version untouched" do
    base_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    base_recording.transition_to!(:transcribing)
    base_recording.update!(transcript: "Cria.")
    base_recording.transition_to!(:transcribed)
    base_recording.transition_to!(:generating)
    base_version = @student.start_periodization!(trainer: @trainer, voice_recording: base_recording)
    base_version.complete!
    periodization = base_version.periodization
    periodization.set_current_version!(base_version)

    edit_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_edit_periodization"
    )
    edit_recording.transition_to!(:transcribing)
    edit_recording.update!(transcript: "Refaz a periodização.")
    edit_recording.transition_to!(:transcribed)
    edit_recording.transition_to!(:generating)
    edit_version = periodization.start_edit!(
      scope: :periodization, trainer: @trainer,
      voice_recording: edit_recording
    )
    edit_version.fail!("LLM indisponível")

    edit_recording.dismiss!

    assert_not_nil edit_recording.reload.dismissed_at
    refute periodization.reload.archived?
    assert_equal base_version.id, periodization.current_version_id
  end

  test "dismiss! on a recording not in :failed is a no-op" do
    recording = build_recording
    assert_equal "pending", recording.status

    recording.dismiss!

    assert_nil recording.reload.dismissed_at
  end

  test "exposes the associated periodization_version through has_one" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @trainer,
      kind: "periodization_create"
    )
    version = @student.start_periodization!(trainer: @trainer, voice_recording: recording)

    assert_equal version, recording.reload.periodization_version
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
