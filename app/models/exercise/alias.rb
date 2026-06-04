# A name (canonical or synonym) that resolves to an Exercise. All Resolution
# goes through this table: `normalized_key` is UNIQUE, so one **Normalized key**
# can point to at most one Exercise. `source` records who minted the alias
# (primary = the Exercise's own name, llm = the Linker, human = manual curation);
# `confidence` is recorded for a future review queue but not gated on in v1.
class Exercise::Alias < ApplicationRecord
  self.table_name = "exercise_aliases"

  belongs_to :exercise, inverse_of: :aliases

  validates :raw_name, presence: true
  validates :normalized_key, presence: true, uniqueness: true
end
