# A name (canonical or synonym) that resolves to an Exercise. All Resolution
# goes through this table: `normalized_key` is UNIQUE, so one **Normalized key**
# can point to at most one Exercise. `source` records who minted the alias
# (primary = the Exercise's own name, llm = the Linker, human = manual curation);
# `confidence` is recorded for a future review queue but not gated on in v1.
class Exercise::Alias < ApplicationRecord
  self.table_name = "exercise_aliases"

  # The recall floor for trigram retrieval. Kept deliberately low — the LLM
  # Linker is the precision filter downstream, so we bias toward surfacing
  # candidates rather than missing a real variant. This and `limit:` are a tuning
  # surface, not a fixed contract.
  SIMILARITY_FLOOR = 0.1

  belongs_to :exercise, inverse_of: :aliases

  validates :raw_name, presence: true
  validates :normalized_key, presence: true, uniqueness: true

  # The recall surface the LLM Linker reranks: given a free-text name, return up
  # to `limit` existing Exercises whose alias corpus is most trigram-similar to
  # the name's Normalized key, ordered by similarity (highest first). Searching
  # every confirmed alias (not just canonical display names) is what lets future
  # name variants find an existing Exercise — recall improves as the catalog
  # learns. Returns an empty array for a blank name or no matches.
  def self.candidates_for(name, limit: 10)
    key = Normalizable.normalize_key(name)
    return [] if key.blank?

    ordered_ids = transaction do
      # Scope the `%` operator's threshold to this query so the GIN index does
      # the recall while keeping the floor low.
      connection.execute("SET LOCAL pg_trgm.similarity_threshold = #{SIMILARITY_FLOOR}")

      where("normalized_key % ?", key)
        .group(:exercise_id)
        .order(Arel.sql(sanitize_sql_array([ "MAX(similarity(normalized_key, ?)) DESC", key ])))
        .limit(limit)
        .pluck(:exercise_id)
    end

    by_id = Exercise.where(id: ordered_ids).index_by(&:id)
    ordered_ids.map { |id| by_id[id] }
  end
end
