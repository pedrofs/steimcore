class TranscribeJob < ApplicationJob
  queue_as :default

  def perform(voice_recording)
    voice_recording.transcribe!
  end
end
