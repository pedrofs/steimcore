require "test_helper"

class TranscribeJobTest < ActiveJob::TestCase
  setup do
    @recording = VoiceRecording.create!(
      organization: organizations(:steimfit),
      student: students(:alice),
      trainer: users(:one),
      kind: "anamnesis"
    )
    @recording.audio.attach(
      io: StringIO.new("fake-audio-bytes"),
      filename: "anamnesis.webm",
      content_type: "audio/webm"
    )
  end

  test "transcribes, auto-advances to :generating, and enqueues the kind-appropriate generation job" do
    transcribe_response = Struct.new(:text).new("Aluno relatou dor lombar.")

    assert_enqueued_with(job: RegenerateAnamnesisJob, args: [ @recording ]) do
      RubyLLM.stub :transcribe, ->(_path, language:) {
        assert_equal "pt", language
        transcribe_response
      } do
        TranscribeJob.perform_now(@recording)
      end
    end

    @recording.reload
    assert_equal "Aluno relatou dor lombar.", @recording.transcript
    assert_equal "generating", @recording.status, "auto-confirm collapses :transcribed into :generating"
    assert_nil @recording.error_message
  end

  test "for a periodization_create kind, transcription starts a generating version and enqueues GeneratePeriodizationJob" do
    recording = VoiceRecording.create!(
      organization: organizations(:steimfit),
      student: students(:alice),
      trainer: users(:one),
      kind: "periodization_create"
    )
    recording.audio.attach(
      io: StringIO.new("fake-audio-bytes"),
      filename: "create.webm",
      content_type: "audio/webm"
    )
    transcribe_response = Struct.new(:text).new("Plano inicial de hipertrofia.")

    assert_difference "PeriodizationVersion.count", 1 do
      assert_enqueued_jobs 1, only: GeneratePeriodizationJob do
        RubyLLM.stub :transcribe, ->(*) { transcribe_response } do
          TranscribeJob.perform_now(recording)
        end
      end
    end

    recording.reload
    assert_equal "generating", recording.status
    version = PeriodizationVersion.find_by!(voice_recording_id: recording.id)
    assert_equal "generating", version.status
  end

  test "marks the recording as failed and preserves the error message when RubyLLM raises" do
    RubyLLM.stub :transcribe, ->(*) { raise RuntimeError, "Whisper indisponível" } do
      TranscribeJob.perform_now(@recording)
    end

    @recording.reload
    assert_equal "failed", @recording.status
    assert_equal "Whisper indisponível", @recording.error_message
    assert_equal "", @recording.transcript
  end

  test "is idempotent — running on a non-pending recording is a no-op" do
    @recording.transition_to!(:transcribing)

    called = false
    RubyLLM.stub :transcribe, ->(*) { called = true; Struct.new(:text).new("x") } do
      TranscribeJob.perform_now(@recording)
    end

    assert_not called, "RubyLLM.transcribe should not be called for a recording already in :transcribing"
    assert_equal "transcribing", @recording.reload.status
  end
end
