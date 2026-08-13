# frozen_string_literal: true

# Read view of a student's active periodization (or any periodization the
# student owns). Creation and edits flow through the agent chat; this
# controller is just the read surface and the entry-point redirect into the
# chat for new plans.
class Students::PeriodizationsController < InertiaController
  before_action :load_student

  # Periodization history: every block the student actually went through,
  # newest first. Blocks without a current_version (a failed generation, or
  # one whose versions were all discarded) never shipped to the student, so
  # they stay out — and the ordinal is numbered over what's listed, keeping
  # the sequence contiguous.
  def index
    @title = "Periodizações — #{@student.name}"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: "Periodizações", path: student_periodizations_path(@student))

    periodizations = @student.periodizations
                             .where.not(current_version_id: nil)
                             .includes(current_version: :workouts)
                             .order(:created_at)

    render inertia: "students/periodizations/index", props: {
      student: { id: @student.id, name: @student.name },
      periodizations: periodizations
        .each_with_index
        .map { |periodization, index| periodization_summary(periodization, ordinal: index + 1) }
        .reverse
    }
  end

  def new
    redirect_to student_agent_chat_path(@student)
  end

  def show
    periodization = @student.periodizations.find(params[:id])
    version = periodization.current_version

    @title = "Periodização — #{@student.name}"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: "Periodizações", path: student_periodizations_path(@student))
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
        progress: progress_props(periodization),
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

    # Sessions-remaining progress, computed per-Periodization (live for the
    # Active one, historical for archived ones). The frontend uses
    # `archived` to neutralize the due/overdue coloring on archived bars,
    # since those signals are forward-looking.
    def progress_props(periodization)
      progress = Student::PeriodizationProgress.new(@student, periodization: periodization)
      return nil unless progress.applicable?

      {
        target: progress.target,
        sessions_done: progress.sessions_done,
        sessions_remaining: progress.sessions_remaining,
        overdue: progress.overdue?,
        due: progress.due?
      }
    end

    # One card on the history list. The split of record is the Current
    # version's — superseded versions may have had a different shape, but the
    # block ended on this one.
    def periodization_summary(periodization, ordinal:)
      version = periodization.current_version

      {
        id: periodization.id,
        ordinal: ordinal,
        archived: periodization.archived?,
        started_on: periodization.created_at.to_date.iso8601,
        ended_on: periodization.archived_at&.to_date&.iso8601,
        length_weeks: version.periodization_length_weeks,
        workouts: version.workouts.sort_by(&:position).map { |w| { id: w.id, name: w.name, position: w.position } },
        progress: progress_props(periodization),
        path: student_periodization_path(@student, periodization)
      }
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
