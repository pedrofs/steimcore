module Agent::Message::Transcribable
  extend ActiveSupport::Concern

  TRANSCRIPT_HEADER = "[Áudio transcrito]".freeze

  def transcribe_voice_clips!
    return unless voice_clips.attached?
    clips = voice_clips.attachments.includes(:blob)
    return if clips.empty?

    # Per-clip idempotency: a clip whose cached transcript text already appears
    # in this message's content was transcribed in a prior turn (possibly while
    # attached to a different message that the heal pass since merged into this
    # one). Skip it so we don't double-append the same transcript.
    pending = clips.reject do |clip|
      cached = clip.blob.metadata["transcript"]
      cached.present? && content.to_s.include?(cached)
    end
    return if pending.empty?

    transcripts = pending.map { |clip| transcript_for(clip) }
    augmented = [ content.presence, TRANSCRIPT_HEADER, *transcripts ].compact.join("\n\n")
    update!(content: augmented)
  end

  private
    def transcript_for(clip)
      blob = clip.blob
      cached = blob.metadata["transcript"]
      return cached if cached.present?

      text = blob.open do |f|
        RubyLLM.transcribe(f.path, language: "pt", assume_model_exists: true, provider: :openai).text.to_s.strip
      end
      blob.update!(metadata: blob.metadata.merge("transcript" => text))
      text
    end
end
