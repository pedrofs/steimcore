# A canonical, globally-shared movement in the Exercise catalog. The AI keeps
# generating free-text **Exercise names** into Block JSON; an async Linking pass
# (a later slice) reconciles those names against this catalog. v1 is fully global
# — no organization scope, no admin role (ADR-0006).
#
# Resolution is uniformly alias-based: every Exercise owns its own canonical name
# as a primary `Exercise::Alias`, and `Exercise.resolve` looks names up through
# the alias corpus only. The canonical id is never written back into Block JSON —
# resolution is read-time (ADR-0006).
class Exercise < ApplicationRecord
  include Normalizable
  include Enrichable
  include MediaTranscoding
  include Mergeable
  include UploadQueue

  # An Exercise is Unenriched on mint (just a name + taxonomy) and becomes
  # Enriched once a trainer attaches media in the Exercises admin.
  enum :state, { unenriched: "unenriched", enriched: "enriched" }, validate: true

  # Both taxonomy slots are nullable on mint; the linker fills them in.
  belongs_to :exercise_family, class_name: "Exercise::Family", optional: true
  belongs_to :muscle_group, class_name: "Exercise::MuscleGroup", optional: true
  # Set when this Exercise is merged into a surviving duplicate (Exercises admin).
  belongs_to :merged_into, class_name: "Exercise", optional: true

  has_many :aliases, class_name: "Exercise::Alias", dependent: :destroy, inverse_of: :exercise

  validates :name, presence: true

  after_create :ensure_primary_alias

  # Resolves a free-text name to its canonical Exercise via the alias corpus, or
  # nil when the name is **Unlinked**. One **Normalized key** maps to at most one
  # Exercise (the unique constraint on aliases).
  def self.resolve(name)
    key = normalize_name(name)
    return nil if key.blank?

    Exercise::Alias.find_by(normalized_key: key)&.exercise
  end

  # The **Exercise suggestion** corpus shipped to every block-editing surface:
  # one row per non-merged Exercise, carrying its canonical name and the
  # **Normalized keys** of all of its Aliases. Shipping server-computed keys is
  # what keeps client-side matching from drifting away from `Normalizable`.
  #
  # The whole corpus rides along as a prop rather than sitting behind an
  # endpoint — the catalog is SteimFit-internal and bounded, the product has no
  # separate JSON API, and client-side filtering is immune to flaky gym wifi.
  def self.suggestions
    where(merged_into_id: nil)
      .order(:name)
      .includes(:aliases)
      .map { |exercise| { id: exercise.id, name: exercise.name, keys: exercise.aliases.map(&:normalized_key).sort } }
  end

  private
    def ensure_primary_alias
      aliases.create!(raw_name: name, normalized_key: self.class.normalize_name(name), source: "primary")
    end
end
