# One row per "the weight for this movement was set", recorded during a live
# training session. The weight is never LLM-generated — the trainer or student
# defines it, and the most recent entry per (student, movement) becomes the
# current value future sessions read back.
#
# Movements (standalone exercise blocks and group items alike) carry no stable
# id in the +blocks+ JSONB, so weight is keyed by the normalized movement name
# (+exercise_key+). This survives workout edits and periodization version forks,
# which rebuild workout rows but keep names.
class ExerciseLoad < ApplicationRecord
  belongs_to :student
  belongs_to :training_session, optional: true

  validates :exercise_name, presence: true
  validates :exercise_key, presence: true
  validates :value, presence: true

  # Folds a movement name to its matching key: accent-stripped, lowercased,
  # trimmed, whitespace-collapsed. Mirrors the client-side `normalizeForSearch`
  # (NFD + strip combining marks) so "Supino  Reto" and "supíno reto" share a
  # weight.
  def self.normalize_name(name)
    string = name.to_s
    string = string.dup.force_encoding(Encoding::UTF_8) unless string.encoding == Encoding::UTF_8
    string = string.scrub("") unless string.valid_encoding?

    string.unicode_normalize(:nfd)
          .gsub(/\p{Mn}/, "")
          .downcase
          .strip
          .gsub(/\s+/, " ")
  end
end
