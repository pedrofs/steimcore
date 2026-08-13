# frozen_string_literal: true

# The "Modelos" library (PRD #170): the trainer-facing screen listing the
# organization's reusable Periodization templates, viewing one rendered the same
# way live plans render, editing one in place (name/description here; workouts via
# PeriodizationTemplates::WorkoutsController), and retiring it. Strictly org-scoped
# — a trainer only ever sees and manages their own organization's templates.
# Templates mutate in place: no version forking, no history (ADR-0008). Retirement
# is a hard `destroy`: nothing references a template, so there is no soft-archive.
class PeriodizationTemplatesController < InertiaController
  with_breadcrumb label: "Modelos", path: -> { periodization_templates_path }

  before_action :load_template, only: [ :show, :edit, :update, :destroy ]

  def index
    @title = "Modelos"

    render inertia: "periodization_templates/index", props: {
      templates: current_organization.periodization_templates.order(:name).map { |template| template_summary(template) }
    }
  end

  def show
    @title = @template.name
    add_breadcrumb(label: @template.name, path: periodization_template_path(@template))

    render inertia: "periodization_templates/show", props: {
      template: template_props(@template)
    }
  end

  def edit
    @title = @template.name
    add_breadcrumb(label: @template.name, path: periodization_template_path(@template))
    add_breadcrumb(label: "Editar", path: edit_periodization_template_path(@template))

    render inertia: "periodization_templates/edit", props: {
      template: template_props(@template),
      # The catalog corpus behind the **Exercise suggestion** autocomplete in
      # the inline workout editor's name fields.
      exercise_suggestions: Exercise.suggestions
    }
  end

  def update
    if @template.update(template_params)
      redirect_to periodization_template_path(@template), notice: "Modelo atualizado."
    else
      redirect_to edit_periodization_template_path(@template),
                  inertia: { errors: @template.errors.to_hash(true) }
    end
  end

  def destroy
    @template.destroy!
    redirect_to periodization_templates_path, notice: "Modelo excluído."
  end

  private
    def load_template
      @template = current_organization.periodization_templates.find(params[:id])
    end

    def template_params
      params.require(:periodization_template).permit(:name, :description)
    end

    def template_summary(template)
      {
        id: template.id,
        name: template.name,
        description: template.description
      }
    end

    def template_props(template)
      {
        id: template.id,
        name: template.name,
        description: template.description,
        body_md: template.body_md,
        workouts: template.workouts.order(:position).map { |workout|
          { id: workout.id, name: workout.name, position: workout.position, blocks: workout.blocks }
        }
      }
    end
end
