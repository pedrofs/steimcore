# A controlled-vocabulary grouping of Exercises (e.g. "Supino", "Agachamento").
# The Linker assigns one flat family per Exercise via `find_or_create_by` on the
# **Normalized key**, so the taxonomy firms up from real usage.
class Exercise::Family < ApplicationRecord
  self.table_name = "exercise_families"

  has_many :exercises, dependent: :nullify

  validates :name, presence: true
  validates :normalized_key, presence: true, uniqueness: true
end
