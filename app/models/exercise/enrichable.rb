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
  end
end
