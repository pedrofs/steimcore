require "test_helper"
require "open3"
require "tmpdir"

class Exercise::MediaTranscoderTest < ActiveSupport::TestCase
  setup do
    skip "ffmpeg not available" unless ffmpeg_available?
    @exercise = Exercise.create!(name: "Agachamento")
    @exercise.media.attach(io: sample_video(width: 1280, height: 720),
      filename: "phone.mov", content_type: "video/quicktime")
    @attachment = @exercise.media.attachments.first
  end

  test "replaces the raw upload with a web-optimized mp4 in place" do
    assert Exercise::MediaTranscoder.pending?(@attachment)
    raw_blob_id = @attachment.blob.id

    Exercise::MediaTranscoder.call(@attachment)

    @exercise.reload
    assert_equal 1, @exercise.media.count, "still exactly one attachment"
    blob = @exercise.media.first.blob
    assert_equal "video/mp4", blob.content_type
    assert blob.filename.to_s.end_with?(".mp4")
    assert_equal "done", blob.metadata["transcode_status"]
    assert blob.metadata["web_optimized"]
    assert_not Exercise::MediaTranscoder.pending?(@exercise.media.first)
    assert_not ActiveStorage::Blob.exists?(raw_blob_id), "the raw upload is purged"
  end

  test "downscales the longer edge to at most 720px" do
    Exercise::MediaTranscoder.call(@attachment)

    width, height = probe_dimensions(@exercise.reload.media.first.blob)
    assert_operator [ width, height ].max, :<=, 720
  end

  test "attaches a poster frame to the optimized blob on success" do
    Exercise::MediaTranscoder.call(@attachment)

    blob = @exercise.reload.media.first.blob
    assert blob.preview_image.attached?, "the optimized blob carries a poster frame"
    assert_equal "done", blob.metadata["transcode_status"], "poster-ready coincides with done"
  end

  test "downscales the poster frame to at most 480px on the longer edge" do
    Exercise::MediaTranscoder.call(@attachment)

    poster = @exercise.reload.media.first.blob.preview_image.blob
    width, height = probe_dimensions(poster)
    assert_operator [ width, height ].max, :<=, 480
  end

  test "a failed transcode attaches no poster frame" do
    @exercise.media.attach(io: StringIO.new("not a video"),
      filename: "noposter.mov", content_type: "video/quicktime")
    broken = @exercise.media.attachments.last

    Exercise::MediaTranscoder.call(broken)

    assert_equal "failed", broken.blob.reload.metadata["transcode_status"]
    assert_not broken.blob.preview_image.attached?, "no poster on a failed transcode"
  end

  test "marks the blob failed and keeps the original when the input is unreadable" do
    @exercise.media.attach(io: StringIO.new("not a video"),
      filename: "broken.mov", content_type: "video/quicktime")
    broken = @exercise.media.attachments.last

    assert_nothing_raised { Exercise::MediaTranscoder.call(broken) }

    assert_equal "failed", broken.blob.reload.metadata["transcode_status"]
    assert_equal "video/quicktime", broken.blob.content_type, "the original is kept"
  end

  test "pending? ignores images and already-optimized videos" do
    @exercise.media.attach(io: StringIO.new("png"), filename: "a.png", content_type: "image/png")
    image = @exercise.media.attachments.last
    assert_not Exercise::MediaTranscoder.pending?(image)

    Exercise::MediaTranscoder.call(@attachment)
    assert_not Exercise::MediaTranscoder.pending?(@exercise.reload.media.first)
  end

  private
    def ffmpeg_available?
      system("ffmpeg -version", out: File::NULL, err: File::NULL)
    end

    def sample_video(width:, height:)
      path = File.join(Dir.mktmpdir, "sample.mp4")
      ok = system(
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "lavfi", "-i", "testsrc=duration=1:size=#{width}x#{height}:rate=10",
        "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", path,
        out: File::NULL, err: File::NULL
      )
      raise "failed to build the sample video fixture" unless ok

      File.open(path, "rb")
    end

    def probe_dimensions(blob)
      blob.open do |file|
        out, _err, _status = Open3.capture3(
          "ffprobe", "-v", "error", "-select_streams", "v:0",
          "-show_entries", "stream=width,height", "-of", "csv=s=x:p=0", file.path
        )
        out.strip.split("x").map(&:to_i)
      end
    end
end
