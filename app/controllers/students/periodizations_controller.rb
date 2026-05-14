# frozen_string_literal: true

# Read view of a student's active periodization (or any periodization the
# student owns). Creation and edits flow through the agent chat; this
# controller is just the read surface and the entry-point redirect into the
# chat for new plans.
class Students::PeriodizationsController < InertiaController
  before_action :load_student

  def new
    redirect_to student_agent_chat_path(@student)
  end

  def show
    periodization = @student.periodizations.find(params[:id])
    version = periodization.current_version

    @title = "Periodização — #{@student.name}"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: "Periodização", path: student_periodization_path(@student, periodization))

    history = periodization.versions
                            .where(status: "completed")
                            .includes(:trainer)
                            .order(:created_at)

    render inertia: "students/periodizations/show", props: {
      student: { id: @student.id, name: @student.name },
      periodization: {
        id: periodization.id,
        archived: periodization.archived?,
        current_version: version && {
          id: version.id,
          body_md: version.body_md,
          workouts: version.workouts.order(:position).map { |w| workout_props(w) }
        },
        versions: history.map { |v| version_summary(v, periodization) }.reverse
      }
    }
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def workout_props(workout)
      {
        id: workout.id,
        name: workout.name,
        position: workout.position,
        blocks: workout.blocks
      }
    end

    def version_summary(version, periodization)
      promoted = version.id == periodization.current_version_id
      {
        id: version.id,
        created_at: version.created_at.iso8601,
        current: promoted,
        draft: !promoted && !version.superseded?,
        trainer: { id: version.trainer_id, email: version.trainer.email_address },
        path: periodization_version_path(version)
      }
    end
end
