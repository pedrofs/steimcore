# frozen_string_literal: true

class TrainingSessionsController < InertiaController
  with_title "Sessões ao vivo"

  ALLOWED_SCOPES = %w[trainer org].freeze

  before_action :load_student,    only: :create
  rescue_from RuntimeError,                  with: :handle_ineligible
  rescue_from ActiveRecord::RecordNotUnique, with: :handle_duplicate_active

  def index
    sessions = scoped_sessions.includes(:student, :trainer).order(:created_at)

    render inertia: "training_sessions/index", props: {
      training_sessions: sessions.map { |s| training_session_props(s) },
      picker_candidates: picker_candidates,
      scope: resolved_scope
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
      redirect_to training_sessions_path,
                  alert: "Aluno já está em sessão ativa. Ative 'Todas' para visualizar."
    end

    def resolved_scope
      ALLOWED_SCOPES.include?(params[:scope]) ? params[:scope] : "trainer"
    end

    def scoped_sessions
      if resolved_scope == "org"
        TrainingSession.active.joins(:student).where(students: { organization_id: current_organization.id })
      else
        Current.user.training_sessions.active
      end
    end

    def picker_candidates
      active_student_ids = TrainingSession.active
                                          .joins(:student)
                                          .where(students: { organization_id: current_organization.id })
                                          .pluck(:student_id)
                                          .to_set

      current_organization.students.unarchived
                          .includes(active_periodization: { current_version: :workouts })
                          .order(:name)
                          .map { |student| picker_candidate_props(student, active_student_ids) }
    end

    def picker_candidate_props(student, active_student_ids)
      reason = ineligibility_reason(student, active_student_ids)
      {
        id: student.id,
        name: student.name,
        eligible: reason.nil?,
        ineligible_reason: reason
      }
    end

    def ineligibility_reason(student, active_student_ids)
      return "already_active" if active_student_ids.include?(student.id)

      version = student.active_periodization&.current_version
      return "no_periodization" if version.nil?
      return "generating" if version.status != "completed"
      return "no_periodization" if version.workouts.empty?

      nil
    end

    def stale_cutoff
      @stale_cutoff ||= TrainingSession::Finishable::STALE_CUTOFF.ago
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
        stale: session.created_at < stale_cutoff,
        trainer_id: session.trainer_id,
        trainer_name: session.trainer.email_address.split("@").first,
        swap_options: session.eligible_swap_workouts.map { |w| { id: w.id, name: w.name, position: w.position } }
      }
    end
end
