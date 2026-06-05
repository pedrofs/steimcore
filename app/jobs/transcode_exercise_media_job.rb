# Web-optimizes an Exercise's freshly uploaded video(s) off the request path: a
# trainer records on a phone, we transcode to a browser-friendly MP4 before it
# ever has to render. A thin wrapper around the work, which lives on the record.
#
# `limits_concurrency` keys on the Exercise so a rapid re-edit can't run two
# transcodes against the same media set at once; different exercises still
# optimize in parallel.
class TranscodeExerciseMediaJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(exercise) { "exercise-media-transcoding-#{exercise.id}" }

  def perform(exercise)
    exercise.transcode_pending_media!
  end
end
