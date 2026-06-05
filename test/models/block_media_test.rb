require "test_helper"

class BlockMediaTest < ActiveSupport::TestCase
  # --- resolution: linked vs unlinked ---

  test "a linked exercise with ready media gets a populated media array" do
    exercise = Exercise.create!(name: "Supino Reto")
    photo = attach_photo(exercise)

    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "Supino Reto", "prescription" => "4x10" }
    ])

    media = blocks[0]["media"]
    assert_equal 1, media.size
    assert_equal photo.id, media[0][:id]
    assert_equal false, media[0][:is_video]
    assert media[0][:thumb_url].present?
    assert media[0][:full_url].present?
  end

  test "an unlinked name gets an empty media array" do
    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "Movimento Inexistente", "prescription" => "3x8" }
    ])

    assert_equal [], blocks[0]["media"]
  end

  test "a linked exercise with no media gets an empty media array" do
    Exercise.create!(name: "Agachamento")

    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "Agachamento", "prescription" => "5x5" }
    ])

    assert_equal [], blocks[0]["media"]
  end

  test "resolution folds accent and case variants onto the same key" do
    exercise = Exercise.create!(name: "Supino Reto")
    attach_photo(exercise)

    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "supíno  reto", "prescription" => "4x10" }
    ])

    assert_equal 1, blocks[0]["media"].size
  end

  # --- block kinds ---

  test "group items are enriched the same way as top-level exercise blocks" do
    rosca = Exercise.create!(name: "Rosca")
    attach_photo(rosca)

    blocks = BlockMedia.with_media([
      { "kind" => "group", "label" => "Bíceps", "items" => [
        { "name" => "Rosca",   "prescription" => "3x12" },
        { "name" => "Martelo", "prescription" => "3x12" }
      ] }
    ])

    items = blocks[0]["items"]
    assert_equal 1, items[0]["media"].size, "linked item gets media"
    assert_equal [], items[1]["media"], "unlinked item gets none"
  end

  test "freeform blocks pass through untouched" do
    blocks = BlockMedia.with_media([
      { "kind" => "freeform", "text_md" => "Aquecimento livre" }
    ])

    assert_equal "freeform", blocks[0]["kind"]
    assert_not blocks[0].key?("media")
  end

  test "merging preserves the block's other keys" do
    exercise = Exercise.create!(name: "Supino")
    attach_photo(exercise)

    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "Supino", "prescription" => "3x8", "weight" => "60kg" }
    ])

    assert_equal "60kg", blocks[0]["weight"]
    assert_equal "3x8", blocks[0]["prescription"]
  end

  # --- readiness filter ---

  test "a processing video is omitted and a done video plus an image are included" do
    exercise = Exercise.create!(name: "Levantamento Terra")
    attach_processing_video(exercise)
    image = attach_photo(exercise)
    video = attach_done_video(exercise)

    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "Levantamento Terra", "prescription" => "5x3" }
    ])

    ids = blocks[0]["media"].map { |m| m[:id] }
    assert_includes ids, image.id
    assert_includes ids, video.id
    assert_equal 2, ids.size, "the still-processing video is filtered out"
  end

  test "a failed video is omitted" do
    exercise = Exercise.create!(name: "Remada")
    attach_failed_video(exercise)

    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "Remada", "prescription" => "4x10" }
    ])

    assert_equal [], blocks[0]["media"]
  end

  # --- ordering ---

  test "the payload leads with a video over a photo" do
    exercise = Exercise.create!(name: "Desenvolvimento")
    attach_photo(exercise)
    video = attach_done_video(exercise)

    blocks = BlockMedia.with_media([
      { "kind" => "exercise", "name" => "Desenvolvimento", "prescription" => "4x8" }
    ])

    media = blocks[0]["media"]
    assert_equal video.id, media[0][:id], "the video comes first"
    assert_equal true, media[0][:is_video]
    assert_equal false, media[1][:is_video]
  end

  # --- bulk resolve / no N+1 ---

  test "the bulk resolve is bounded by distinct keys, not block count" do
    a = Exercise.create!(name: "Supino")
    attach_photo(a)
    b = Exercise.create!(name: "Agachamento")
    attach_done_video(b)

    two = [
      { "kind" => "exercise", "name" => "Supino",      "prescription" => "3x8" },
      { "kind" => "exercise", "name" => "Agachamento", "prescription" => "5x5" }
    ]
    many = (1..20).flat_map { two }

    small = count_queries { BlockMedia.with_media(two) }
    large = count_queries { BlockMedia.with_media(many) }

    assert_equal small, large, "ten times the blocks must not mean more queries"
  end

  test "non-array input passes through" do
    assert_nil BlockMedia.with_media(nil)
  end

  private
    def attach_photo(exercise)
      exercise.media.attach(io: StringIO.new("png-bytes"), filename: "photo.png", content_type: "image/png")
      exercise.media.attachments.last
    end

    def attach_processing_video(exercise)
      exercise.media.attach(io: StringIO.new("raw"), filename: "raw.mov", content_type: "video/quicktime")
      exercise.media.attachments.last
    end

    def attach_done_video(exercise)
      exercise.media.attach(io: StringIO.new("mp4"), filename: "clip.mp4", content_type: "video/mp4")
      attachment = exercise.media.attachments.last
      blob = attachment.blob
      blob.update!(metadata: blob.metadata.to_h.merge("transcode_status" => "done"))
      blob.preview_image.attach(io: StringIO.new("poster"), filename: "clip.jpg", content_type: "image/jpeg")
      attachment
    end

    def attach_failed_video(exercise)
      exercise.media.attach(io: StringIO.new("bad"), filename: "bad.mov", content_type: "video/quicktime")
      attachment = exercise.media.attachments.last
      blob = attachment.blob
      blob.update!(metadata: blob.metadata.to_h.merge("transcode_status" => "failed"))
      attachment
    end

    def count_queries(&block)
      count = 0
      counter = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA"
        next if payload[:sql] =~ /\A\s*(BEGIN|COMMIT|RELEASE|SAVEPOINT|ROLLBACK)/i
        count += 1
      end
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
