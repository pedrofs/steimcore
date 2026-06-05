# frozen_string_literal: true

# The "Modelos" library (PRD #170): the trainer-facing screen listing the
# organization's reusable Periodization templates, viewing one rendered the same
# way live plans render, and retiring it. Strictly org-scoped — a trainer only
# ever sees and manages their own organization's templates. Retirement is a hard
# `destroy` (ADR-0008): nothing references a template, so there is no soft-archive.
class PeriodizationTemplatesController < InertiaController
  with_breadcrumb label: "Modelos", path: -> { periodization_templates_path }

  before_action :load_template, only: [ :show, :destroy ]

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

  def destroy
    @template.destroy!
    redirect_to periodization_templates_path, notice: "Modelo excluído."
  end

  private
    def load_template
      @template = current_organization.periodization_templates.find(params[:id])
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
