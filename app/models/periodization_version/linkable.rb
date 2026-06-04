# The async **Linking** pass that reconciles a completed version's free-text
# Exercise names against the global catalog (ADR-0006). This slice is the
# pipeline *minus the intelligence*: no trigram retrieval and no LLM — every
# name that doesn't already resolve simply mints its own Unenriched Exercise.
# Retrieval (#166) and the LLM Classifier (#167) graft onto `#link_exercises!`
# later without changing this contract.
#
# AI generation stays completely free-form; linking only reconciles after the
# fact, on every completed version (not just the promoted one).
module PeriodizationVersion::Linkable
  extend ActiveSupport::Concern

  # The distinct movement names across the whole version — every `exercise`
  # block's name and every `group` item's name, deduplicated by **Normalized
  # key** (first occurrence wins, so a usable raw name survives for minting).
  # `freeform` blocks are prose and never contribute.
  def exercise_names
    by_key = {}
    workouts.each do |workout|
      Array(workout.blocks).each do |block|
        names_in(block).each do |name|
          key = Exercise.normalize_name(name)
          by_key[key] ||= name unless key.blank?
        end
      end
    end
    by_key.values
  end

  # Resolves every name and mints an Unenriched Exercise for each one not
  # already in the catalog. Idempotent and safe to re-run: a name that already
  # resolves is skipped, and the UNIQUE(normalized_key) constraint backstops
  # concurrent runs racing on the same novel name.
  def link_exercises!
    exercise_names.each { |name| mint_unless_resolvable(name) }
  end

  private
    def names_in(block)
      case block["kind"]
      when "exercise" then [ block["name"] ]
      when "group"    then Array(block["items"]).map { |item| item["name"] }
      else []
      end
    end

    def mint_unless_resolvable(name)
      key = Exercise.normalize_name(name)
      return if key.blank?
      return if Exercise::Alias.exists?(normalized_key: key)

      Exercise.create!(name: name)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent linking run minted this name's primary alias between our
      # check and insert; the UNIQUE(normalized_key) backstop won — nothing to do.
    end
end
