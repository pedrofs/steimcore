require "open3"
require "tmpdir"

# Web-optimizes one attached Exercise video in place. Trainers record demos on a
# phone — often HEVC in a `.mov` that desktop Chrome/Firefox won't play, at full
# sensor resolution — so the raw upload is hostile to the browser. This transcodes
# it to a broadly-compatible H.264/AAC MP4, downscaled and `faststart`-flagged for
# instant playback, then swaps the raw upload for the result and purges it.
#
# Internal collaborator of the Exercise model; the public API stays on the record
# (`exercise.transcode_pending_media!`, driven by TranscodeExerciseMediaJob). The
# optimized blob is tagged `transcode_status: "done"` so it is never re-processed.
class Exercise::MediaTranscoder
  class TranscodeError < StandardError; end

  # Cap the longer edge. Exercise clips render in a small square card, so 720px
  # keeps them crisp while shrinking a 1080p/4K phone capture by an order of
  # magnitude. Audio is re-encoded to AAC for the same compatibility reason.
  MAX_DIMENSION = 720
  # Constant Rate Factor — 23 is FFmpeg's visually-transparent default for H.264.
  CRF = 23
  AUDIO_BITRATE = "128k"

  class << self
    def call(attachment)
      new(attachment).call
    end

    # A video attachment is pending exactly while it carries no transcode verdict:
    # a fresh upload (blank) needs work; "done"/"failed" are terminal. Images never
    # qualify — they're already web-friendly.
    def pending?(attachment)
      blob = attachment.blob
      blob.content_type.to_s.start_with?("video/") &&
        blob.metadata.to_h["transcode_status"].blank?
    end
  end

  def initialize(attachment)
    @attachment = attachment
    @blob = attachment.blob
  end

  # Downloads the raw upload, transcodes it, and replaces the attachment's blob
  # with the optimized MP4. On any failure the original is kept and flagged
  # "failed" so the UI stops waiting and still shows the (raw) clip.
  def call
    return unless self.class.pending?(@attachment)

    @blob.open do |source|
      Dir.mktmpdir("exercise-media") do |dir|
        output = File.join(dir, "optimized.mp4")
        transcode(source.path, output)
        File.open(output, "rb") { |io| replace_blob_with(io) }
      end
    end
  rescue => e
    Rails.logger.error("[Exercise::MediaTranscoder] blob=#{@blob.id} #{e.class}: #{e.message}")
    mark("failed")
  end

  private
    def transcode(input_path, output_path)
      _out, err, status = Open3.capture3(*ffmpeg_command(input_path, output_path))
      raise TranscodeError, err.to_s.lines.last(5).join unless status.success?
    end

    def ffmpeg_command(input_path, output_path)
      [
        "ffmpeg", "-y", "-nostdin", "-loglevel", "error",
        "-i", input_path,
        "-vf", scale_filter,
        "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
        "-preset", "veryfast", "-crf", CRF.to_s,
        "-c:a", "aac", "-b:a", AUDIO_BITRATE, "-ac", "2",
        "-movflags", "+faststart",
        "-map_metadata", "-1",
        output_path
      ]
    end

    # Downscale so the longer edge is at most MAX_DIMENSION, preserving aspect and
    # never upscaling (`min(cap, …)`); then round both edges to even, which
    # yuv420p requires. FFmpeg auto-rotates by the display matrix before this runs,
    # so portrait phone clips come out upright even after `-map_metadata -1`.
    def scale_filter
      "scale=" \
        "'if(gt(iw,ih),min(#{MAX_DIMENSION},iw),-2)':" \
        "'if(gt(iw,ih),-2,min(#{MAX_DIMENSION},ih))'," \
        "scale=trunc(iw/2)*2:trunc(ih/2)*2"
    end

    def replace_blob_with(io)
      optimized = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: optimized_filename,
        content_type: "video/mp4",
        identify: false,
        metadata: { "transcode_status" => "done", "web_optimized" => true }
      )
      previous = @blob
      @attachment.update!(blob: optimized)
      previous.purge
    end

    def optimized_filename
      "#{File.basename(@blob.filename.to_s, '.*')}.mp4"
    end

    def mark(status)
      @blob.update!(metadata: @blob.metadata.to_h.merge("transcode_status" => status))
    end
end
