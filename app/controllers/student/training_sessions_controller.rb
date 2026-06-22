class Student::TrainingSessionsController < Student::ApplicationController
  before_action :require_selected_profile
  before_action :load_session, only: [ :show, :destroy ]
  before_action :ensure_student_initiated, only: :destroy
  rescue_from RuntimeError,                  with: :handle_ineligible
  rescue_from ActiveRecord::RecordNotUnique, with: :resume_active_session

  def create
    session = Current.student.start_training_session!(workout: chosen_workout)
    track "session_started",
      training_session_id: session.id,
      workout_position: session.workout_position_snapshot,
      blocks_count: session.blocks_snapshot.size
    redirect_to student_training_session_path(session)
  end

  def show
    render inertia: "student/training_sessions/show", props: {
      session: Student::LiveSessionView.new(@session).to_h
    }
  end

  # Cancel = hard delete: discards the session, recording nothing toward
  # progress/frequency, and frees the one-active slot so the student can start
  # again. Distinct from finishing (#completion stamps finished_at). Guarded to
  # student-initiated sessions by +ensure_student_initiated+.
  def destroy
    # Capture the abandonment shape before the row is gone — a cancel hard-deletes
    # the session, so this event is the only trace it ever leaves.
    cancelled = {
      training_session_id: @session.id,
      blocks_total: @session.blocks_snapshot.size,
      blocks_completed: @session.progress.size,
      age_seconds: (Time.current - @session.created_at).round
    }
    @session.destroy!
    track "session_cancelled", **cancelled
    redirect_to student_home_path, notice: "Sessão cancelada."
  end

  private
    # The workout the student picked in the home chooser, scoped to their own
    # current version so a forged id can't start a workout from another plan.
    # Blank or unrecognized ids fall back to nil, which start! resolves to the
    # auto-suggested next workout.
    def chosen_workout
      return if params[:workout_id].blank?

      Current.student.active_periodization&.current_version&.workouts&.find_by(id: params[:workout_id])
    end

    def load_session
      @session = Current.student.training_sessions.find(params[:id])
    end

    # A student may only cancel sessions they started themselves; a trainer-led
    # session can be finished but never discarded by the student.
    def ensure_student_initiated
      return if @session.student_initiated?

      redirect_to student_training_session_path(@session),
                  alert: "Você só pode cancelar sessões que você iniciou."
    end

    # Rest-day lockout and the start! eligibility guards both raise plain
    # RuntimeErrors with a Portuguese message; surface them as a flash on home.
    def handle_ineligible(exception)
      redirect_to student_home_path, alert: exception.message
    end

    # A double-tap / concurrent start trips the one-active-per-student unique
    # index. Rather than error, resolve to the single active session so the
    # student lands on the live screen they already own.
    def resume_active_session(_exception)
      session = Current.student.active_training_session
      if session
        redirect_to student_training_session_path(session)
      else
        redirect_to student_home_path
      end
    end
end
