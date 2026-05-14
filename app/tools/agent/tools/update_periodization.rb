module Agent
  module Tools
    # Revises the student's active periodization. Operates on
    # `student.active_periodization.current_version`:
    #
    # - If the current version is `read_only?` (promoted or superseded),
    #   a new draft version is forked from it and the patch lands there.
    # - Otherwise the patch mutates the editable draft in place — iterative
    #   refinement of an unpromoted draft doesn't spawn near-duplicate
    #   versions, matching the same semantics the existing voice-edit flow
    #   uses.
    #
    # Returns a soft `{error: ...}` shape when no active periodization
    # exists (suggesting `create_periodization`) or when the patch's blocks
    # fail `Workout::Blocks.errors_for`.
    class UpdatePeriodization < RubyLLM::Tool
      description <<~DESC
        Revisa a periodização ativa do aluno por inteiro (body markdown +
        todos os treinos). Use para mudanças de plano (ex.: "adiciona uma
        semana de deload", "reorganiza para 4x por semana"). O aluno precisa
        ter uma periodização ativa — se ainda não existe, use
        `create_periodization`. Para mexer em apenas um treino, use
        `update_workout`.
      DESC

      params PeriodizationSchema.full_plan_params

      def name
        "update_periodization"
      end

      attr_accessor :current_tool_call_llm_id

      def initialize(student:, trainer:)
        super()
        @student = student
        @trainer = trainer
      end

      def execute(body_md:, workouts:, summary_md:)
        summary_md = summary_md.to_s.strip
        return { error: "Faltou um resumo curto (`summary_md`) descrevendo a alteração." } if summary_md.empty?

        @student.reload
        periodization = @student.active_periodization
        return { error: "Aluno não tem periodização ativa. Use `create_periodization` para começar uma nova." } if periodization.nil?

        latest = PeriodizationToolHelpers.latest_version(periodization)
        return { error: "A periodização ativa ainda não tem uma versão para revisar." } if latest.nil?

        if (errors = validate_workouts(workouts)).any?
          return { error: errors.join("; ") }
        end

        patch = { body_md: body_md.to_s, workouts: workouts }
        target_version = nil

        ActiveRecord::Base.transaction do
          target_version = if latest.read_only?
            # current_version must be set to fork via start_edit!; that's only true
            # after promotion (which is what made `latest` read_only here).
            periodization.set_current_version!(latest) if periodization.current_version_id != latest.id
            new_version = periodization.start_edit!(scope: :periodization, trainer: @trainer)
            new_version.fork_with!(scope: :periodization, patch: patch, trainer: @trainer)
            new_version.complete!
            new_version
          else
            latest.apply_patch!(scope: :periodization, patch: patch, trainer: @trainer)
            latest
          end

          target_version.update!(agent_tool_call: resolve_agent_tool_call)
        end

        {
          ok: true,
          version_id: target_version.id,
          version_number: PeriodizationToolHelpers.version_number(target_version),
          scope: "periodization",
          workout_count: target_version.workouts.count,
          summary_md: summary_md
        }
      end

      private
        def validate_workouts(workouts)
          return [ "workouts deve ser uma lista não vazia" ] unless workouts.is_a?(Array) && workouts.any?

          workouts.flat_map.with_index do |workout, index|
            blocks = workout.is_a?(Hash) ? (workout["blocks"] || workout[:blocks]) : nil
            Workout::Blocks.errors_for(blocks).map { |msg| "treino #{index}: #{msg}" }
          end
        end

        def resolve_agent_tool_call
          return nil if @current_tool_call_llm_id.blank?
          Agent::ToolCall.find_by(tool_call_id: @current_tool_call_llm_id)
        end
    end
  end
end
