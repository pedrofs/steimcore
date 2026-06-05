# The Exercises admin curation step (PRD #163). Confirming the taxonomy and
# attaching media (photo/video) is one logical write, and the Unenriched/Enriched
# state is *derived* from media presence: an Exercise reads as Enriched exactly
# when it has media attached, Unenriched otherwise. Wrong media is strictly worse
# than no media, so media presence — not a free-floating flag — is the source of
# truth for the state.
module Exercise::Enrichable
  extend ActiveSupport::Concern

  included do
    has_many_attached :media
  end

  class_methods do
    # Enqueue an LLM taxonomy backfill for every Unenriched Exercise still missing
    # a family or muscle group — i.e. the names the Linker blind-minted without
    # trigram candidates. Idempotent: rows a trainer or the Classifier already
    # classified are skipped by the filter (and again by `enrich_taxonomy!`).
    def enrich_unclassified_later
      unclassified.find_each { |exercise| EnrichExerciseJob.perform_later(exercise) }
    end

    # Unenriched Exercises with at least one empty taxonomy slot.
    def unclassified
      unenriched.where(exercise_family_id: nil).or(unenriched.where(muscle_group_id: nil))
    end
  end

  # LLM-proposes the Exercise family + primary Muscle group for a name the Linker
  # left blank, filling only the empty slots so a trainer's (or the Classifier's)
  # classification is never clobbered. Taxonomy alone does not flip the state —
  # only attached media does — so this stays Unenriched, ready for media curation.
  def enrich_taxonomy!
    return if exercise_family && muscle_group

    decision = Exercise::Enricher.classify(self)
    self.exercise_family ||= Exercise::Family.for_name(decision[:family])
    self.muscle_group    ||= Exercise::MuscleGroup.for_name(decision[:muscle_group])
    save! if changed?
  end

  # Confirms the Exercise family / Muscle group and attaches any new media in one
  # transaction, then folds the state to match media presence. A nil taxonomy
  # slot clears it; passing no media leaves existing attachments untouched.
  # Attaching media is what flips an Exercise to Enriched.
  def enrich(exercise_family: nil, muscle_group: nil, media: nil)
    transaction do
      self.exercise_family = exercise_family
      self.muscle_group = muscle_group
      self.media.attach(media) if media.present?
      self.state = self.media.attached? ? :enriched : :unenriched
      save!
    end

    # Optimize any raw video the trainer just attached once the row is committed,
    # so the background job reads the persisted attachments. A no-op for
    # taxonomy-only edits and image uploads (see Exercise::MediaTranscoding).
    enqueue_media_transcoding
  end
end
