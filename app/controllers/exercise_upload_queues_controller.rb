# frozen_string_literal: true

# The video-upload queue: a camera-first curation screen listing the Unenriched
# Exercises still missing media, ranked by how heavily workouts reference them
# (Exercise::UploadQueue). A trainer films down the list — each capture posts to
# Exercises::MediaController#create, flips that Exercise to Enriched, and it drops
# off the queue on the next render.
class ExerciseUploadQueuesController < InertiaController
  with_breadcrumb label: "Fila de vídeos", path: -> { exercise_upload_queue_path }

  def show
    @title = "Fila de vídeos"

    render inertia: "exercise_upload_queue/show", props: {
      exercises: Exercise.upload_queue.map { |exercise, count| queue_item(exercise, count) }
    }
  end

  private
    def queue_item(exercise, count)
      {
        id: exercise.id,
        name: exercise.name,
        family: exercise.exercise_family&.name,
        muscle_group: exercise.muscle_group&.name,
        usage_count: count
      }
    end
end
