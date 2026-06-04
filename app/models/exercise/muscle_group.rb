# A controlled-vocabulary primary muscle group (e.g. "Peito", "Quadríceps").
# v1 tracks a single primary muscle group per Exercise (no synergists). The
# Linker assigns it via `find_or_create_by` on the **Normalized key**.
class Exercise::MuscleGroup < ApplicationRecord
  self.table_name = "exercise_muscle_groups"

  has_many :exercises, foreign_key: :muscle_group_id, dependent: :nullify, inverse_of: :muscle_group

  validates :name, presence: true
  validates :normalized_key, presence: true, uniqueness: true
end
