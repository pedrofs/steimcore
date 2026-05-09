class PurgeOldAudioJob < ApplicationJob
  queue_as :default

  def perform
    VoiceRecording.purge_audio_older_than(VoiceRecording::AUDIO_RETENTION)
  end
end
