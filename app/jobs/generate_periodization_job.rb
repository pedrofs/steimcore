# Claude boundary for periodization generation. Receives a PeriodizationVersion
# in :generating with a confirmed transcript on its voice_recording, builds a
# pt-BR prompt that combines the student context (structured fields +
# anamnesis_md), the organization's equipment list, and the trainer transcript,
# and asks Claude — via RubyLLM with a schema — to produce the structured plan
# `{ body_md, workouts: [{ name, content_md, position }] }`. On success, the
# patch is applied to the version through `Forkable#fork_with!(scope: :create)`
# and the version transitions to :completed for the trainer to review. Any
# schema-invalid response or RubyLLM error marks the version :failed with the
# message preserved for retry.
class GeneratePeriodizationJob < ApplicationJob
  queue_as :default

  MODEL = "claude-sonnet-4-5"

  SCHEMA = {
    name: "periodization_plan",
    schema: {
      type: "object",
      additionalProperties: false,
      required: %w[body_md workouts],
      properties: {
        body_md: { type: "string" },
        workouts: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[name content_md position],
            properties: {
              name: { type: "string" },
              content_md: { type: "string" },
              position: { type: "integer" }
            }
          }
        }
      }
    }
  }.freeze

  def perform(version_id)
    version = PeriodizationVersion.find(version_id)
    return unless version.status == "generating"

    student = version.periodization.student
    organization = student.organization
    recording = version.voice_recording

    chat = RubyLLM.chat(model: MODEL).with_instructions(system_prompt).with_schema(SCHEMA)
    response = chat.ask(user_prompt(student, organization, recording&.transcript.to_s))

    plan = parse_plan(response.content)
    validate_plan!(plan)

    version.fork_with!(
      scope: :create,
      patch: plan,
      trainer: version.trainer,
      voice_recording: recording
    )
    version.transition_to!(:completed)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    version&.fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end

  private
    def parse_plan(content)
      case content
      when Hash then content
      when String
        begin
          JSON.parse(content)
        rescue JSON::ParserError => e
          raise InvalidPlanError, "resposta não é JSON válido: #{e.message}"
        end
      else
        raise InvalidPlanError, "resposta vazia"
      end
    end

    def validate_plan!(plan)
      raise InvalidPlanError, "campo body_md ausente" unless plan["body_md"].is_a?(String) || plan[:body_md].is_a?(String)

      workouts = plan["workouts"] || plan[:workouts]
      raise InvalidPlanError, "campo workouts ausente ou inválido" unless workouts.is_a?(Array) && workouts.any?

      workouts.each_with_index do |w, i|
        name = w["name"] || w[:name]
        content_md = w["content_md"] || w[:content_md]
        position = w["position"] || w[:position]

        raise InvalidPlanError, "workout #{i}: nome inválido" unless name.is_a?(String) && !name.strip.empty?
        raise InvalidPlanError, "workout #{i}: content_md inválido" unless content_md.is_a?(String)
        raise InvalidPlanError, "workout #{i}: position inválida" unless position.is_a?(Integer)
      end
    end

    def system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é montar uma periodização de treino para um aluno, em
        português do Brasil. A saída deve ser um plano estruturado com um corpo
        em markdown (visão geral do mesociclo, princípios, progressão) e uma
        lista de treinos (A, B, C, …), cada um com nome curto, conteúdo em
        markdown (lista de exercícios, séries, repetições, observações) e uma
        posição inteira a partir de 1. Use apenas equipamentos disponíveis na
        academia. Não invente dados que o treinador não tenha mencionado. Não
        mencione que você é uma IA.
      PROMPT
    end

    def user_prompt(student, organization, transcript)
      <<~PROMPT
        ## Aluno
        Nome: #{student.name}
        Idade: #{student.age || "(não informada)"}
        Sexo: #{student.sex || "(não informado)"}
        Objetivo principal: #{student.primary_goal || "(não informado)"}
        Frequência semanal: #{student.weekly_frequency || "(não informada)"}
        Restrições resumidas: #{student.restrictions_summary.presence || "(nenhuma)"}

        ## Anamnese atual
        #{student.anamnesis_md.presence || "(vazia)"}

        ## Equipamentos da academia
        #{organization.equipment_list_md.presence || "(não informado)"}

        ## Instruções do treinador (transcritas)
        #{transcript.presence || "(vazias)"}

        ## Tarefa
        Gere a periodização estruturada. Inclua um body_md com o plano geral e
        a lista de treinos (workouts) numerados em ordem de execução semanal.
      PROMPT
    end

    class InvalidPlanError < StandardError; end
end
