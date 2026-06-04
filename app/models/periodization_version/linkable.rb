# The async **Linking** pass that reconciles a completed version's free-text
# Exercise names against the global catalog (ADR-0006). Each unresolved name is
# routed by trigram retrieval: no candidates → mint a new Unenriched Exercise
# directly (no LLM); candidates present → the `Exercise::Linker::Classifier`
# decides whether the name is a variant of an existing Exercise (attach an Alias)
# or genuinely new (mint, classified into an Exercise family + Muscle group).
#
# Bias-to-split: any uncertain or "new" decision mints rather than merges, because
# showing the wrong media is strictly worse than showing none.
#
# AI generation stays completely free-form; linking only reconciles after the
# fact, on every completed version (not just the promoted one). Idempotent and
# safe to re-run: a name that already resolves is skipped, and the
# UNIQUE(normalized_key) constraint backstops concurrent runs racing the same name.
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

  # Reconciles every unresolved name against the catalog. Candidates are
  # retrieved up front (a snapshot, so a mint earlier in this run can't perturb a
  # sibling's candidate set); names with none are minted directly, the rest go to
  # the Classifier in a single batch.
  def link_exercises!
    retrievals = unresolved_names.map { |name| [ name, Exercise::Alias.candidates_for(name) ] }
    novel, ambiguous = retrievals.partition { |_name, candidates| candidates.empty? }

    novel.each { |name, _| mint_unenriched(name) }
    classify_and_persist(ambiguous) if ambiguous.any?
  end

  private
    def names_in(block)
      case block["kind"]
      when "exercise" then [ block["name"] ]
      when "group"    then Array(block["items"]).map { |item| item["name"] }
      else []
      end
    end

    def unresolved_names
      exercise_names.reject { |name| Exercise::Alias.exists?(normalized_key: Exercise.normalize_name(name)) }
    end

    # The no-candidate path: trigram retrieval found nothing, so the name is novel
    # by construction — mint without consulting the LLM.
    def mint_unenriched(name)
      key = Exercise.normalize_name(name)
      return if key.blank?
      return if Exercise::Alias.exists?(normalized_key: key)

      Exercise.create!(name: name)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent run minted this name's primary alias first; the
      # UNIQUE(normalized_key) backstop won — nothing to do.
    end

    def classify_and_persist(ambiguous)
      items = ambiguous.map do |name, candidates|
        { id: Exercise.normalize_name(name), name: name,
          candidates: candidates.map { |ex| { exercise_id: ex.id, name: ex.name } } }
      end
      by_id = Exercise::Linker::Classifier.classify(items).index_by { |d| d[:id] }

      ambiguous.each do |name, candidates|
        persist_decision(name, candidates, by_id[Exercise.normalize_name(name)])
      end
    end

    def persist_decision(name, candidates, decision)
      key = Exercise.normalize_name(name)
      return if Exercise::Alias.exists?(normalized_key: key)

      if (matched = matched_candidate(decision, candidates))
        matched.aliases.create!(raw_name: name, normalized_key: key, source: "llm", confidence: decision[:confidence])
      else
        mint_classified(name, key, decision)
      end
    rescue ActiveRecord::RecordNotUnique
      # A concurrent run canonized this normalized key first; the unique
      # constraint is the correctness backstop and there's nothing to add.
    end

    # A "match" only counts when the chosen id is actually one of the candidates
    # we offered; anything else falls through to a mint (bias-to-split).
    def matched_candidate(decision, candidates)
      return nil unless decision && decision[:decision].to_s == "match"

      candidates.find { |ex| ex.id == decision[:exercise_id] }
    end

    def mint_classified(name, key, decision)
      family = find_or_create_taxonomy(Exercise::Family, decision&.dig(:family))
      muscle = find_or_create_taxonomy(Exercise::MuscleGroup, decision&.dig(:muscle_group))

      Exercise.transaction do
        exercise = Exercise.create!(
          name: decision&.dig(:display_name).presence || name,
          exercise_family: family,
          muscle_group: muscle
        )
        # The auto-created primary alias covers the display name; ensure the
        # triggering name resolves too when it normalizes differently.
        ensure_alias(exercise, name, key, decision&.dig(:confidence))
      end
    end

    def ensure_alias(exercise, raw_name, key, confidence)
      return if exercise.aliases.exists?(normalized_key: key)

      exercise.aliases.create!(raw_name: raw_name, normalized_key: key, source: "llm", confidence: confidence)
    end

    # Find-or-create on the Normalized key, which also dedups within a batch: the
    # first "new" decision for a name persists the node, later ones find it.
    def find_or_create_taxonomy(model, choice)
      return nil if choice.blank?

      if (id = choice[:existing_id]).present?
        model.find_by(id: id)
      elsif (new_name = choice[:new]).present?
        model.find_or_create_by!(normalized_key: Exercise.normalize_name(new_name)) { |node| node.name = new_name }
      end
    end
end
