# Consolidation in the Exercises admin (PRD #163): folding a duplicate Exercise
# into a surviving one. Because Linking biases toward splitting under uncertainty,
# near-duplicate Unenriched Exercises accumulate, and a trainer merges them by
# hand (there is no automated consolidation sweep in v1).
#
# Merging repoints every one of the loser's Aliases onto the survivor and records
# the survivor in `merged_into`, so every name that used to resolve to the loser
# now resolves to the survivor. The alias `normalized_key` is globally UNIQUE, so
# the repoint can never collide — each normalized key lives on exactly one
# Exercise, and the loser's keys are by definition absent from the survivor.
module Exercise::Mergeable
  extend ActiveSupport::Concern

  # Folds this (loser) Exercise into `target`: repoints every Alias onto the
  # target and records the merge. Wrapped in a transaction so a failed repoint
  # never leaves a dangling `merged_into`. Raises ArgumentError when asked to
  # merge an Exercise into itself (a no-op that would orphan the catalog entry).
  def merge_into!(target)
    raise ArgumentError, "cannot merge an exercise into itself" if target == self

    transaction do
      aliases.update_all(exercise_id: target.id)
      update!(merged_into: target)
    end
  end
end
