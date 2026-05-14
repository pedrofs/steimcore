module Agent
  module Tools
    # Creates a brand-new periodization for the student. Returns a soft
    # `{error: ...}` shape on the documented domain failures (validation
    # against the block schema; an active periodization already exists) so
    # the agent can self-correct and switch tools — typically to
    # `update_periodization`.
    #
    # On success, the resulting `PeriodizationVersion` row carries
    # `agent_tool_call_id` pointing back to the `Agent::ToolCall` row that
    # produced it, so the chat card can deep-link to the version.
    class CreatePeriodization < RubyLLM::Tool
      description <<~DESC
        Cria uma nova periodização para o aluno (em estado de esboço, não
        promovida). Use quando o aluno ainda não tem periodização ativa, ou
        quando o treinador pede explicitamente um plano novo do zero. Para
        revisar um plano existente, use `update_periodization`; para mexer em
        apenas um treino, use `update_workout`.
      DESC

      params PeriodizationSchema.full_plan_params

      def name
        "create_periodization"
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
        if @student.active_periodization.present?
          return { error: "Aluno já tem periodização ativa. Use `update_periodization` para revisar ou `update_workout` para alterar um treino." }
        end

        if (errors = validate_workouts(workouts)).any?
          return { error: errors.join("; ") }
        end

        version = nil
        ActiveRecord::Base.transaction do
          version = @student.start_periodization!(trainer: @trainer)
          version.fork_with!(
            scope: :create,
            patch: { body_md: body_md.to_s, workouts: workouts },
            trainer: @trainer
          )
          version.complete!
          version.update!(agent_tool_call: resolve_agent_tool_call)
        end

        {
          ok: true,
          version_id: version.id,
          version_number: PeriodizationToolHelpers.version_number(version),
          scope: "create",
          workout_count: version.workouts.count,
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
