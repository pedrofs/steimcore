class TrainingSession
  # Pure index arithmetic behind a **Mid-session edit** (ADR-0009). A session's
  # +progress+ is a list of stringified block indices, so any change to the
  # blocks array would silently reattribute the student's ticks unless the marks
  # are rewritten along with it.
  #
  # +origin_indices+ carries one entry per submitted block: the index that block
  # occupied in the session's previous +blocks_snapshot+, or nil when the block
  # was just added. An entry whose old index survives maps to that block's new
  # position; an old index that is absent (the block was removed) is dropped;
  # a new block is never born done.
  #
  # Deliberately free of ActiveRecord — the trickiest part of the operation is
  # exercised without fixtures or a database.
  class ProgressRemap
    INDEX_FORMAT = /\A\d+\z/

    def self.remap(progress:, origin_indices:)
      new(progress: progress, origin_indices: origin_indices).to_a
    end

    def initialize(progress:, origin_indices:)
      @progress = progress
      @origin_indices = origin_indices
    end

    # The rewritten progress: stringified indices, deduplicated and ascending.
    def to_a
      (@progress || []).filter_map { |entry| new_position_for(entry) }.uniq.sort.map(&:to_s)
    end

    private
      def new_position_for(entry)
        old_index = index_from(entry)
        old_index && positions_by_origin[old_index]
      end

      # First occurrence wins when the same origin is listed twice: the earliest
      # surviving copy of a duplicated block inherits the tick.
      def positions_by_origin
        @positions_by_origin ||= (@origin_indices || []).each_with_index.each_with_object({}) do |(origin, position), map|
          old_index = index_from(origin)
          map[old_index] = position if old_index && !map.key?(old_index)
        end
      end

      def index_from(value)
        case value
        when Integer then value
        when String  then Integer(value) if value.match?(INDEX_FORMAT)
        end
      end
  end
end
