# Backfills LLM-proposed taxonomy onto one Unenriched Exercise the Linker minted
# without trigram candidates (so the Classifier never classified it). A thin
# wrapper around the work, which lives on the record.
#
# `limits_concurrency to: 1` under a single global key serializes enrichment runs
# so taxonomy nodes firm up sequentially: a later Exercise sees the families /
# muscle groups earlier ones coined and reuses them instead of racing to mint a
# duplicate. The UNIQUE(normalized_key) constraint on the taxonomy tables is the
# correctness backstop independent of the queue.
class EnrichExerciseJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "exercise-enrichment"

  def perform(exercise)
    exercise.enrich_taxonomy!
  end
end
