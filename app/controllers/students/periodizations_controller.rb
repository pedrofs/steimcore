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

    history = periodization.versions
                            .where(status: "completed")
                            .includes(:trainer, :voice_recording)
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
        versions: history.map { |v| version_summary(v, periodization) }
      }
    }
  end

  private
    TRANSCRIPT_EXCERPT_LIMIT = 240

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

    def version_summary(version, periodization)
      transcript = version.voice_recording&.transcript.to_s
      {
        id: version.id,
        created_at: version.created_at.iso8601,
        current: version.id == periodization.current_version_id,
        trainer: { id: version.trainer_id, email: version.trainer.email_address },
        transcript_excerpt: transcript.truncate(TRANSCRIPT_EXCERPT_LIMIT),
        path: periodization_version_path(version)
      }
    end
end
