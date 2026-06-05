# frozen_string_literal: true

# The Exercises admin (PRD #163): the trainer-facing screen for curating the
# global Exercise catalog. Fully global — no organization scope and no admin role
# in v1 (ADR-0006); every trainer browses the same catalog and enriches an
# Exercise from Unenriched to Enriched by attaching media and confirming its
# Exercise family / Muscle group. Merged-away duplicates are hidden from the list
# (consolidation lands as its own sub-resource).
class ExercisesController < InertiaController
  with_breadcrumb label: "Exercícios", path: -> { exercises_path }

  rescue_from Pagy::OverflowError, with: :redirect_to_last_page

  before_action :load_exercise, only: [ :show, :edit, :update ]

  STATES = Exercise.states.keys.freeze

  def index
    @title = "Exercícios"
    filters = index_filters
    @pagy, exercises = pagy(filtered_exercises(filters), limit: 25)

    render inertia: "exercises/index", props: {
      exercises: exercises.map { |exercise| exercise_summary(exercise) },
      pagination: pagination_props(@pagy),
      filters: filters
    }
  end

  def show
    @title = @exercise.name
    add_breadcrumb(label: @exercise.name, path: exercise_path(@exercise))

    render inertia: "exercises/show", props: {
      exercise: exercise_props(@exercise),
      merge_targets: merge_targets(@exercise)
    }
  end

  def edit
    @title = "Editar #{@exercise.name}"
    add_breadcrumb(label: @exercise.name, path: exercise_path(@exercise))
    add_breadcrumb(label: "Editar", path: edit_exercise_path(@exercise))

    render inertia: "exercises/edit", props: { exercise: exercise_props(@exercise) }
  end

  def update
    @exercise.enrich(
      exercise_family: Exercise::Family.for_name(update_params[:exercise_family_name]),
      muscle_group: Exercise::MuscleGroup.for_name(update_params[:muscle_group_name]),
      media: update_params[:media]
    )

    redirect_to exercise_path(@exercise), notice: "Exercício atualizado."
  end

  private
    def load_exercise
      @exercise = catalog.find(params[:id])
    end

    # Merged-away Exercises have been consolidated into a survivor and must never
    # surface in the admin.
    def catalog
      Exercise.where(merged_into_id: nil)
    end

    def update_params
      params.require(:exercise).permit(:exercise_family_name, :muscle_group_name, media: [])
    end

    def index_filters
      { q: params[:q].to_s, state: (params[:state] if STATES.include?(params[:state])) }
    end

    def filtered_exercises(filters)
      scope = catalog.includes(:exercise_family, :muscle_group).with_attached_media
      scope = scope.where(state: filters[:state]) if filters[:state]

      if filters[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(filters[:q])}%"
        name_matches = Exercise.where("name ILIKE ?", like).select(:id)
        alias_matches = Exercise::Alias.where("raw_name ILIKE ?", like).select(:exercise_id)
        scope = scope.where(id: name_matches).or(scope.where(id: alias_matches))
      end

      scope.order(:name)
    end

    def exercise_summary(exercise)
      {
        id: exercise.id,
        name: exercise.name,
        family: exercise.exercise_family&.name,
        muscle_group: exercise.muscle_group&.name,
        state: exercise.state,
        has_media: exercise.media.attached?
      }
    end

    # Every other live Exercise is a candidate survivor to fold this one into.
    # The catalog is SteimFit-internal and bounded, so the full list is fine as a
    # prop; the merge picker on the detail page selects from it.
    def merge_targets(exercise)
      catalog.where.not(id: exercise.id).order(:name).pluck(:id, :name).map do |id, name|
        { id:, name: }
      end
    end

    def exercise_props(exercise)
      {
        id: exercise.id,
        name: exercise.name,
        family: exercise.exercise_family&.name,
        muscle_group: exercise.muscle_group&.name,
        state: exercise.state,
        aliases: exercise.aliases.order(:raw_name).map { |a| { raw_name: a.raw_name, source: a.source } },
        media: exercise.media.map { |attachment| media_props(attachment) }
      }
    end

    def media_props(attachment)
      blob = attachment.blob
      is_video = blob.content_type.to_s.start_with?("video/")
      status = blob.metadata.to_h["transcode_status"]

      {
        id: attachment.id,
        filename: blob.filename.to_s,
        content_type: blob.content_type,
        url: rails_blob_path(attachment, only_path: true),
        is_video: is_video,
        # A raw video is still being optimized until its blob earns a verdict;
        # "failed" falls back to playing the original (see Exercise::MediaTranscoder).
        processing: is_video && status.blank?,
        failed: status == "failed"
      }
    end

    def pagination_props(pagy)
      {
        page: pagy.page,
        pages: pagy.pages,
        count: pagy.count,
        from: pagy.from,
        to: pagy.to,
        prev: pagy.prev,
        next: pagy.next,
        series: pagy.series
      }
    end

    def redirect_to_last_page(exception)
      redirect_to url_for(request.query_parameters.merge(page: exception.pagy.last))
    end
end
