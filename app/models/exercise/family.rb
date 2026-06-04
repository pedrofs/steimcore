# A controlled-vocabulary grouping of Exercises (e.g. "Supino", "Agachamento").
# The Linker assigns one flat family per Exercise via `find_or_create_by` on the
# **Normalized key**, so the taxonomy firms up from real usage.
class Exercise::Family < ApplicationRecord
  self.table_name = "exercise_families"

  has_many :exercises, dependent: :nullify

  validates :name, presence: true
  validates :normalized_key, presence: true, uniqueness: true

  # Find-or-create the family node for a free-text name, keyed on the shared
  # Normalized key so the Exercises admin and the Linker can never coin two nodes
  # for the same name. Returns nil for a blank name.
  def self.for_name(name)
    key = Normalizable.normalize_key(name)
    return nil if key.blank?

    find_or_create_by!(normalized_key: key) { |node| node.name = name.strip }
  end
end
