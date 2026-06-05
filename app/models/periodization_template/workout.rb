# A template's workout — a parallel table to `workouts`, byte-shaped like a
# version's workout so the inline editor, BlocksRenderer, and clone all reuse
# existing paths (ADR-0008). Shares the `Blocks` schema validation via
# `Blockable`, but deliberately carries NONE of `Workout`'s version machinery:
# no `belongs_to :periodization_version`, no `relink` callback (linking is a
# version concern that fires when a cloned version reaches `:completed`).
class PeriodizationTemplate
  class Workout < ApplicationRecord
    self.table_name = "periodization_template_workouts"

    include Blockable

    belongs_to :periodization_template

    validates :name, presence: true
    validates :position, presence: true, numericality: { only_integer: true }

    default_scope -> { order(:position) }
  end
end
