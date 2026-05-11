# Whisper boundary owned by the recording. Downloads the attached audio,
# calls RubyLLM.transcribe(language: "pt"), writes the result to `transcript`,
# and walks :pending → :transcribing → :transcribed → :generating in one pass,
# enqueueing the kind-appropriate generation job. There is no trainer-facing
# confirmation step; :transcribed is transient. Any exception is captured as a
# :failed transition with the message preserved on the row.
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
    send(:confirm_transcript!)
  rescue StandardError => e
    fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end
end
