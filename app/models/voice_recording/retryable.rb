# Smart retry for a failed VoiceRecording. Picks the resume point based on
# what we already have: blank transcript means transcription itself failed
# (re-run Whisper); transcript-present means generation failed (re-run the
# kind-appropriate generation job, resetting the associated PeriodizationVersion
# alongside the recording for periodization kinds).
module VoiceRecording::Retryable
  extend ActiveSupport::Concern

  def retry!
    return unless status == "failed"

    if transcript.blank?
      reset_for_transcription!
    elsif kind == "anamnesis"
      reset_for_anamnesis_generation!
    else
      reset_for_periodization_generation!
    end
  end

  private
    def reset_for_transcription!
      transaction do
        self.error_message = nil
        transition_to!(:pending)
        TranscribeJob.perform_later(self)
      end
    end

    def reset_for_anamnesis_generation!
      transaction do
        self.error_message = nil
        transition_to!(:generating)
        RegenerateAnamnesisJob.perform_later(self)
      end
    end

    def reset_for_periodization_generation!
      version = periodization_version
      raise "voice_recording=#{id} has no periodization_version to retry" if version.nil?

      transaction do
        self.error_message = nil
        transition_to!(:generating)
        version.error_message = nil
        version.transition_to!(:generating)
        GeneratePeriodizationJob.perform_later(version)
      end
    end
end
