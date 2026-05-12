# frozen_string_literal: true

class TrainingSessionsController < InertiaController
  with_title "Sessões ao vivo"

  before_action :load_student,    only: :create
  rescue_from RuntimeError,                  with: :handle_ineligible
  rescue_from ActiveRecord::RecordNotUnique, with: :handle_duplicate_active

  def index
    sessions = Current.user.training_sessions
                      .active
                      .includes(:student)
                      .order(:created_at)

    render inertia: "training_sessions/index", props: {
      training_sessions: sessions.map { |s| training_session_props(s) },
      picker_candidates: picker_candidates,
      scope: "trainer"
    }
  end

  def create
    Current.user.training_sessions.start_for!(@student)
    redirect_to training_sessions_path
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def handle_ineligible(exception)
      redirect_to training_sessions_path, alert: exception.message
    end

    def handle_duplicate_active(_exception)
      redirect_to training_sessions_path, alert: "Aluno já tem uma sessão ativa."
    end

    def picker_candidates
      active_student_ids = TrainingSession.active
                                          .joins(:student)
                                          .where(students: { organization_id: current_organization.id })
                                          .select(:student_id)

      current_organization.students.unarchived
                          .joins(active_periodization: { current_version: :workouts })
                          .where(periodization_versions: { status: "completed" })
                          .where.not(id: active_student_ids)
                          .distinct
                          .order(:name)
                          .map { |student| { id: student.id, name: student.name } }
    end

    def training_session_props(session)
      {
        id: session.id,
        student: { id: session.student_id, name: session.student.name },
        workout_id: session.workout_id,
        workout_name: session.workout_name_snapshot,
        workout_position: session.workout_position_snapshot,
        blocks: session.blocks_snapshot,
        completed_block_indices: session.progress,
        finished_at: session.finished_at,
        created_at: session.created_at,
        trainer_id: session.trainer_id
      }
    end
end
