# Whisper boundary owned by the recording. Downloads the attached audio,
# calls RubyLLM.transcribe(language: "pt"), writes the result to `transcript`
# and transitions :pending → :transcribing → :transcribed. Any exception is
# captured as a :failed transition with the message preserved on the row.
module VoiceRecording::Transcribable
  extend ActiveSupport::Concern

  def transcribe!
    return unless status == "pending"

    transition_to!(:transcribing)

    text = audio.blob.open do |file|
      response = RubyLLM.transcribe(file.path, language: "pt")
      response.text
    end

    update!(transcript: text)
    transition_to!(:transcribed)
  rescue StandardError => e
    fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end
end
