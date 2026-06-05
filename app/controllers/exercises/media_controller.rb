# frozen_string_literal: true

# Single-tap capture from the upload queue: attaching one freshly recorded clip to
# an Exercise. The bytes are uploaded straight to storage from the browser (Active
# Storage direct upload), so #create only receives the resulting blob `signed_id`,
# hands it to the model, and bounces back to the queue. Modeled as a sub-resource
# of an Exercise rather than a custom verb on ExercisesController (project RESTful
# convention) and kept separate from exercises#update, which rewrites taxonomy.
class Exercises::MediaController < InertiaController
  before_action :load_exercise
  before_action :ensure_unenriched

  def create
    @exercise.attach_media!(params.require(:media))

    redirect_to exercise_upload_queue_path, notice: "Mídia de #{@exercise.name} enviada."
  end

  private
    # Merged-away Exercises are hidden from the admin and can't receive media.
    def load_exercise
      @exercise = Exercise.where(merged_into_id: nil).find(params[:exercise_id])
    end

    # v1 films each Exercise once: an already-Enriched one has its clip and leaves
    # the queue, so a late capture (two trainers racing the same card) is a no-op.
    def ensure_unenriched
      return if @exercise.unenriched?

      redirect_to exercise_upload_queue_path, notice: "#{@exercise.name} já tem mídia."
    end
end
