# frozen_string_literal: true

# The **Mid-session edit** endpoint (ADR-0009). The trainer's live board PATCHes
# `{ workout: { blocks: [...] }, origin_indices: [...], blocks_digest: "..." }`
# and the plan itself is revised: a new PeriodizationVersion is forked from the
# current one, promoted, and the live session re-pointed at it with the
# student's progress remapped. The payload mirrors
# PeriodizationVersions::WorkoutsController so one editor serves both surfaces.
#
# Ownership is deliberately not a guard: any trainer in the organization can
# edit any session on the board, matching how toggling, swapping and removal
# already behave. `origin_indices` is a sibling parameter — nothing transient is
# ever persisted into the blocks JSONB.
class TrainingSessions::WorkoutsController < InertiaController
  before_action :load_session
  before_action :ensure_session_active
  before_action :ensure_session_attached
  before_action :ensure_blocks_unchanged
  rescue_from TrainingSession::WorkoutRevisable::InvalidBlocks, with: :handle_invalid_blocks

  def update
    @session.revise_workout!(
      blocks: submitted_blocks,
      origin_indices: submitted_origin_indices,
      trainer: Current.user
    )

    redirect_back fallback_location: training_sessions_path,
                  notice: "Treino atualizado no plano do aluno."
  end

  private
    def load_session
      @session = TrainingSession.joins(:student)
                                .where(students: { organization_id: current_organization.id })
                                .find(params[:training_session_id])
    end

    def ensure_session_active
      return if @session.finished_at.nil?

      redirect_back fallback_location: training_sessions_path,
                    alert: "Esta sessão já foi finalizada e não pode ser editada."
    end

    def ensure_session_attached
      return unless @session.detached?

      redirect_back fallback_location: training_sessions_path,
                    alert: "O plano deste aluno mudou desde o início da sessão. Recarregue a página."
    end

    def ensure_blocks_unchanged
      return if submitted_digest == @session.blocks_digest

      redirect_back fallback_location: training_sessions_path,
                    alert: "Este treino foi alterado por outra pessoa. Recarregue a página e tente novamente."
    end

    def revision_params
      @revision_params ||= params.permit(
        :blocks_digest,
        origin_indices: [],
        workout: [ blocks: [
          :kind, :name, :prescription, :rest_s, :notes, :text_md, :label, :rounds,
          { items: [ :name, :prescription, :notes ] }
        ] ]
      ).to_h
    end

    def submitted_digest
      revision_params[:blocks_digest].to_s
    end

    # A payload with no blocks key at all is malformed, not an instruction to
    # empty the workout: reject it rather than let a botched request blank a
    # student's prescription. An explicit empty array is a real submission.
    def submitted_blocks
      revision_params.dig(:workout, :blocks) || raise(ActionController::ParameterMissing.new(:blocks))
    end

    # One entry per submitted block: the index it held in the session's previous
    # blocks snapshot, or a blank entry for a block the trainer just added.
    # Blank rather than JSON null because Rails' deep_munge compacts nils out of
    # parameter arrays — a null-encoded new block would silently shift every
    # later block's origin by one. The model API keeps nil as "newly added".
    def submitted_origin_indices
      Array(revision_params[:origin_indices]).map(&:presence)
    end

    def handle_invalid_blocks(exception)
      redirect_back fallback_location: training_sessions_path,
                    inertia: { errors: { blocks: exception.messages } }
    end
end
