# Validates the JSONB `blocks` column against the shared `Blocks` schema. Mixed
# into both `Workout` (live-plan content) and `PeriodizationTemplate::Workout`
# (blueprint content) so the two editors reject the same malformed blocks with
# byte-identical pt-BR messages. The "refactor when the second user appears"
# convention (ADR-0008): extracted once template workouts arrived.
module Blockable
  extend ActiveSupport::Concern

  included do
    validate :validate_blocks_schema
  end

  private
    def validate_blocks_schema
      Blocks.errors_for(blocks).each { |message| errors.add(:blocks, message) }
    end
end
