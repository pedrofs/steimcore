# The video-upload queue (the camera-first curation screen): the Unenriched
# Exercises a trainer should film next, ranked by how heavily they're used across
# workouts. There is no FK from workouts to exercises — `workout.blocks` reference
# movements by free-text **name** — so usage is computed by walking every block
# name, folding it to its Normalized key, and attributing the count to the
# Exercise that key resolves to via the alias corpus (Exercise::Alias).
module Exercise::UploadQueue
  extend ActiveSupport::Concern

  class_methods do
    # Unenriched, non-merged Exercises that workouts actually reference, ranked by
    # total reference count desc, then name. Returns `[[exercise, count], ...]`.
    # Enriched exercises (those with media) and names that resolve to no Exercise
    # are absent by construction, so the queue self-empties as clips land.
    def upload_queue
      counts = usage_counts
      return [] if counts.empty?

      per_exercise = Hash.new(0)
      # One Normalized key maps to at most one Exercise (UNIQUE on
      # exercise_aliases.normalized_key), and an Exercise can own several aliases,
      # so summing each of its keys' counts is correct and folds name variants in.
      Exercise::Alias.where(normalized_key: counts.keys)
                     .pluck(:normalized_key, :exercise_id)
                     .each { |key, exercise_id| per_exercise[exercise_id] += counts[key] }

      unenriched.where(merged_into_id: nil, id: per_exercise.keys)
                .includes(:exercise_family, :muscle_group)
                .map { |exercise| [ exercise, per_exercise[exercise.id] ] }
                .sort_by { |exercise, count| [ -count, exercise.name ] }
    end

    # Histogram of total exercise-name references across ALL workouts, keyed by the
    # Normalized key. The walk over every workout's blocks is the expensive part, so
    # it's cached on the workout set: both `max(updated_at)` and `count` shift on any
    # create/update/destroy, busting the entry. Alias attribution stays live in
    # #upload_queue, so freshly-linked aliases reflect without waiting on this cache.
    def usage_counts
      Rails.cache.fetch([ "exercise_usage_counts", Workout.maximum(:updated_at), Workout.count ]) do
        Workout.find_each.each_with_object(Hash.new(0)) do |workout, counts|
          workout.exercise_names.each do |name|
            key = normalize_name(name)
            counts[key] += 1 if key.present?
          end
        end
      end
    end
  end
end
