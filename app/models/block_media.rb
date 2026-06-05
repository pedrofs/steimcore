# Read-time media enrichment for the JSONB +blocks+ tree, sibling to Blocks.
# Takes any blocks array and merges a +media+ array onto each +exercise+ block
# and each group +item+; +freeform+ blocks pass through untouched. The canonical
# Exercise id is never written into the snapshot — media is resolved live, at
# read time, from the catalog (ADR-0006), so a clip attached after a session
# started shows up the next time the page loads.
#
# The merge is a single bulk resolve: it collects the distinct Normalized keys
# across every block, runs one aliased query (Exercise::Alias by normalized_key)
# with media attachments, blobs and their poster frames eager-loaded, and builds
# a key → media[] map. No per-name Exercise.resolve in a loop — the query count
# is bounded by the distinct key count, not by how many blocks (or workouts) are
# on the page.
#
# Per-exercise payload (consumption shape, snake_case across the Inertia boundary):
#   media: [{ id, thumb_url, full_url, is_video }]
# Ordering puts videos first, then photos, so the primary thumbnail leads with a
# video when one exists; the drawer consumes the whole array. Only fully-processed
# media is included: images always; videos only once their transcode is "done"
# (poster-ready). +processing+ and +failed+ videos are filtered out.
module BlockMedia
  # The poster/photo thumbnail cap. Video posters are already produced at this
  # size by Exercise::MediaTranscoder; images get a matching resize_to_limit
  # variant so the page loads a lightweight thumbnail up front.
  THUMB_LIMIT = [ 480, 480 ].freeze

  module_function

  def with_media(blocks)
    return blocks unless blocks.is_a?(Array)

    media_by_key = resolve(distinct_keys(blocks))

    blocks.map do |block|
      case block["kind"]
      when "exercise"
        block.merge("media" => media_for(media_by_key, block["name"]))
      when "group"
        block.merge("items" => Array(block["items"]).map { |item|
          item.merge("media" => media_for(media_by_key, item["name"]))
        })
      else
        block
      end
    end
  end

  class << self
    private

    def media_for(media_by_key, name)
      media_by_key[Exercise.normalize_name(name)] || []
    end

    def distinct_keys(blocks)
      blocks.flat_map { |block|
        case block["kind"]
        when "exercise" then block["name"]
        when "group"    then Array(block["items"]).map { |item| item["name"] }
        else []
        end
      }.map { |name| Exercise.normalize_name(name) }.reject(&:blank?).uniq
    end

    # One aliased query for every distinct key, with the resolved Exercises'
    # media attachments, blobs and poster frames eager-loaded. Keys that don't
    # resolve, and Exercises with no ready media, simply never enter the map.
    def resolve(keys)
      return {} if keys.empty?

      aliases = Exercise::Alias
        .where(normalized_key: keys)
        .includes(exercise: { media_attachments: { blob: { preview_image_attachment: :blob } } })

      aliases.each_with_object({}) do |alias_record, map|
        payload = payload_for(alias_record.exercise)
        map[alias_record.normalized_key] = payload if payload.any?
      end
    end

    def payload_for(exercise)
      videos, photos = exercise.media.attachments.partition { |attachment| video?(attachment.blob) }

      (videos.filter_map { |attachment| video_item(attachment) } +
        photos.map { |attachment| photo_item(attachment) })
    end

    def video?(blob)
      blob.content_type.to_s.start_with?("video/")
    end

    # A video joins the payload only once it is fully processed: a "done" verdict
    # plus the poster frame it earns alongside it. A still-+processing+ (blank) or
    # +failed+ clip is filtered out — the surface shows no thumbnail at all.
    def video_item(attachment)
      blob = attachment.blob
      return nil unless blob.metadata.to_h["transcode_status"] == "done"
      return nil unless blob.preview_image.attached?

      {
        id: attachment.id,
        thumb_url: blob_path(blob.preview_image),
        full_url: blob_path(attachment),
        is_video: true
      }
    end

    def photo_item(attachment)
      {
        id: attachment.id,
        thumb_url: representation_path(attachment.blob.variant(resize_to_limit: THUMB_LIMIT)),
        full_url: blob_path(attachment),
        is_video: false
      }
    end

    def blob_path(attachment_or_blob)
      routes.rails_blob_path(attachment_or_blob, only_path: true)
    end

    def representation_path(representation)
      routes.rails_representation_path(representation, only_path: true)
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
