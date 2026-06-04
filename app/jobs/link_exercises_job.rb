# Reconciles a completed Periodization version's Exercise names against the
# global catalog. A thin wrapper around the work, which lives on the record.
#
# `limits_concurrency to: 1` under a single global key serializes all linking
# runs so completed versions link one at a time — preventing double-canonization
# and letting each run see the prior run's new aliases. The UNIQUE(normalized_key)
# constraint is the correctness backstop independent of the queue.
class LinkExercisesJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "exercise-linking"

  def perform(version)
    version.link_exercises!
  end
end
