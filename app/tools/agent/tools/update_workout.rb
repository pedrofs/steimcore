module Agent
  module Tools
    # Edits a single workout inside the student's active periodization. The
    # `workout_id` is the UUID of a workout belonging to
    # `student.active_periodization.current_version` — workouts on archived
    # or earlier versions are immutable history and are rejected.
    #
    # Like `update_periodization`, this respects the fork-or-mutate
    # semantics: read-only current_version → fork a new draft and edit the
    # workout there; editable draft → mutate in place.
    class UpdateWorkout < RubyLLM::Tool
      description <<~DESC
        Edita um único treino da periodização ativa do aluno (ex.: "no Treino
        A troca supino por crucifixo"). Use quando o treinador quer mexer em
        UM treino específico sem reescrever o plano todo. Para mudar o plano
        inteiro, use `update_periodization`. Para criar uma periodização do
        zero, use `create_periodization`.
      DESC

      params PeriodizationSchema.workout_patch_params

      def name
        "update_workout"
      end

      attr_accessor :current_tool_call_llm_id

      def initialize(student:, trainer:)
        super()
        @student = student
        @trainer = trainer
      end

      def execute(workout_id:, name:, blocks:, summary_md:)
        summary_md = summary_md.to_s.strip
        return { error: "Faltou um resumo curto (`summary_md`) descrevendo a alteração." } if summary_md.empty?

        @student.reload
        periodization = @student.active_periodization
        return { error: "Aluno não tem periodização ativa. Use `create_periodization` para começar uma nova." } if periodization.nil?

        latest = PeriodizationToolHelpers.latest_version(periodization)
        return { error: "A periodização ativa ainda não tem uma versão para revisar." } if latest.nil?

        target_workout = latest.workouts.find_by(id: workout_id.to_s)
        return { error: "Treino não encontrado na versão atual da periodização." } if target_workout.nil?

        block_errors = Workout::Blocks.errors_for(blocks)
        return { error: block_errors.join("; ") } if block_errors.any?

        if name.to_s.strip.empty?
          return { error: "Nome do treino não pode ficar em branco." }
        end

        patch = { workout: { name: name.to_s, blocks: blocks } }
        target_version = nil
        result_workout = nil

        ActiveRecord::Base.transaction do
          target_version = if latest.read_only?
            periodization.set_current_version!(latest) if periodization.current_version_id != latest.id
            new_version = periodization.start_edit!(scope: :workout, trainer: @trainer, target_workout: target_workout)
            new_version.fork_with!(scope: :workout, patch: patch, trainer: @trainer, target_workout: target_workout)
            new_version.complete!
            new_version
          else
            latest.apply_patch!(scope: :workout, patch: patch, trainer: @trainer, target_workout: target_workout)
            latest
          end

          target_version.update!(agent_tool_call: resolve_agent_tool_call)
          result_workout = target_version.workouts.find_by(position: target_workout.position)
        end

        {
          ok: true,
          version_id: target_version.id,
          version_number: PeriodizationToolHelpers.version_number(target_version),
          workout_id: result_workout.id,
          workout_name: result_workout.name,
          summary_md: summary_md
        }
      end

      private
        def resolve_agent_tool_call
          return nil if @current_tool_call_llm_id.blank?
          Agent::ToolCall.find_by(tool_call_id: @current_tool_call_llm_id)
        end
    end
  end
end
