# Keeps raw phone uploads out of the browser. Trainers attach exercise demos
# recorded on their phones — oversized and often in a codec/container the web
# can't play — so every attached video is transcoded to a web-optimized MP4 (see
# Exercise::MediaTranscoder) by a background job, in place. The `media` association
# a page renders therefore converges to something every browser can play; until a
# clip is optimized it reports as still processing (its blob carries no
# `transcode_status`), which the detail page surfaces as an "optimizing" state.
module Exercise::MediaTranscoding
  extend ActiveSupport::Concern

  class_methods do
    # Backfill / repair: (re)optimize every Exercise still holding a raw video —
    # clips attached before this shipped, or jobs that died mid-flight (a crash
    # leaves the blob un-verdicted, i.e. pending, so it is picked up again here).
    def transcode_pending_media_later
      with_attached_media.find_each(&:enqueue_media_transcoding)
    end
  end

  # Optimizes each not-yet-optimized attached video in place. Idempotent: images
  # and already-optimized videos are skipped, so it is safe to re-run.
  def transcode_pending_media!
    pending_video_attachments.each { |attachment| Exercise::MediaTranscoder.call(attachment) }
  end

  # Enqueues optimization only when a raw video is actually waiting — taxonomy-only
  # edits and image-only uploads never spawn a job.
  def enqueue_media_transcoding
    TranscodeExerciseMediaJob.perform_later(self) if pending_video_attachments.any?
  end

  private
    def pending_video_attachments
      media.attachments.select { |attachment| Exercise::MediaTranscoder.pending?(attachment) }
    end
end
