# Whisper boundary. Receives a VoiceRecording in :pending, downloads the
# attached audio, calls RubyLLM.transcribe(language: "pt"), writes the result
# to `transcript` and transitions to :transcribed. Any exception is recorded as
# a :failed transition with the message preserved on the row so the trainer
# can decide whether to retry.
class TranscribeJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id)
    recording = VoiceRecording.find(voice_recording_id)
    return unless recording.status == "pending"

    recording.transition_to!(:transcribing)

    text = recording.audio.blob.open do |file|
      response = RubyLLM.transcribe(file.path, language: "pt")
      response.text
    end

    recording.update!(transcript: text)
    recording.transition_to!(:transcribed)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    recording&.fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end
end
