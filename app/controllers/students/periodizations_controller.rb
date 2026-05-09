# frozen_string_literal: true

# Read view of a student's active periodization (or any periodization the
# student owns). The flow that creates a periodization runs through the voice
# recording pipeline (`kind: :periodization_create`); this controller is just
# the read surface and the entry-point redirect into that pipeline.
class Students::PeriodizationsController < InertiaController
  before_action :load_student

  def new
    redirect_to new_student_voice_recording_path(@student, kind: "periodization_create")
  end

  def show
    periodization = @student.periodizations.find(params[:id])
    version = periodization.current_version

    @title = "Periodização — #{@student.name}"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: "Periodização", path: student_periodization_path(@student, periodization))

    render inertia: "students/periodizations/show", props: {
      student: { id: @student.id, name: @student.name },
      periodization: {
        id: periodization.id,
        archived: periodization.archived?,
        current_version: version && {
          id: version.id,
          body_md: version.body_md,
          workouts: version.workouts.order(:position).map { |w| workout_props(w) }
        }
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
        content_md: workout.content_md
      }
    end
end
