# The LLM precision filter in the Linking pipeline (ADR-0006). Trigram retrieval
# (`Exercise::Alias.candidates_for`) hands this a batch of unresolved names that
# each have at least one plausible existing Exercise; the Classifier decides, per
# name, whether the name is a variant of one of those candidates (attach an Alias)
# or a genuinely new movement (mint an Exercise classified into an Exercise family
# and a primary Muscle group). It wraps a single structured `RubyLLM` call on the
# Claude Opus tier — the same model the per-student agent uses.
#
# Bias-to-split: the prompt instructs the model to answer `new` whenever it is not
# confident the name is the same movement as a candidate, because showing the
# wrong exercise media is strictly worse than showing none.
#
# The decision contract returned to `PeriodizationVersion::Linkable` is keyed by
# each item's stable `id` (the Normalized key), never array position:
#
#   { id:, decision: "match" | "new",
#     exercise_id:,                       # when "match"
#     display_name:,                      # when "new"
#     family:       { existing_id: } | { new: "<name>" } | nil,
#     muscle_group: { existing_id: } | { new: "<name>" } | nil,
#     confidence: }                       # 0.0..1.0, stored but not gated in v1
#
# The full Exercise family and Muscle group vocabularies are enumerated into the
# prompt (small controlled tables) so the model can reuse a node or coin a new one.
# The real LLM call is covered at the system level; unit tests stub `.classify`.
class Exercise::Linker::Classifier
  # Matches the per-student agent's tier (`StudentAgent`).
  MODEL = "claude-opus-4-7"

  # The flat structured-output contract. Family/Muscle group are expressed as two
  # mutually-exclusive scalar fields rather than a nested oneOf — predictable for
  # the model and trivially mapped back to the `{ existing_id: } | { new: }` shape
  # `Linkable` expects.
  class DecisionSchema < RubyLLM::Schema
    array :decisions do
      object do
        string :id, description: "O id estável do item, idêntico ao recebido."
        string :decision, enum: %w[match new],
               description: "match = variante de um candidato; new = movimento novo."
        string :exercise_id, required: false,
               description: "id do Exercise candidato escolhido, obrigatório quando decision=match."
        string :display_name, required: false,
               description: "nome canônico do novo Exercise, quando decision=new."
        string :family_existing_id, required: false,
               description: "id de uma Exercise family existente, quando decision=new e uma serve."
        string :family_new_name, required: false,
               description: "nome de uma nova Exercise family, quando decision=new e nenhuma existente serve."
        string :muscle_group_existing_id, required: false,
               description: "id de um Muscle group existente, quando decision=new e um serve."
        string :muscle_group_new_name, required: false,
               description: "nome de um novo Muscle group, quando decision=new e nenhum existente serve."
        number :confidence, description: "Confiança da decisão, de 0.0 a 1.0."
      end
    end
  end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Você é o classificador de um catálogo de exercícios de musculação. Para cada
    item recebido, decida se o nome é uma variante de um dos Exercises candidatos
    (decision="match") ou um movimento genuinamente novo (decision="new").

    Regras:
    - "match" só quando você tem certeza de que é o MESMO movimento de um candidato
      (ex.: "Supino reto" e "supino reto com barra"). Devolva o exercise_id desse
      candidato.
    - Na dúvida, escolha "new". Mostrar o vídeo errado é pior do que não mostrar
      nenhum — prefira criar um Exercise novo a fundir incorretamente.
    - Para "new", devolva um display_name limpo e classifique em UMA Exercise family
      e UM Muscle group. Reutilize um id existente quando algum servir; caso
      contrário, proponha um nome novo (family_new_name / muscle_group_new_name).
    - Sempre devolva o mesmo id que recebeu em cada item e uma confidence entre 0 e 1.
  PROMPT

  def self.classify(items)
    new(items).classify
  end

  def initialize(items)
    @items = Array(items)
  end

  def classify
    return [] if @items.empty?

    chat = RubyLLM.chat(model: MODEL)
    chat.with_schema(DecisionSchema)
    chat.with_instructions(SYSTEM_PROMPT)
    response = chat.ask(payload.to_json)

    decisions_from(response.content)
  end

  private
    def payload
      {
        exercise_families: Exercise::Family.order(:name).map { |f| { id: f.id, name: f.name } },
        muscle_groups: Exercise::MuscleGroup.order(:name).map { |m| { id: m.id, name: m.name } },
        items: @items
      }
    end

    def decisions_from(content)
      rows = content.is_a?(Hash) ? (content["decisions"] || content[:decisions]) : nil
      Array(rows).map { |row| normalize_decision(row.to_h.symbolize_keys) }
    end

    def normalize_decision(row)
      {
        id: row[:id],
        decision: row[:decision],
        exercise_id: row[:exercise_id],
        display_name: row[:display_name],
        family: taxonomy_choice(row[:family_existing_id], row[:family_new_name]),
        muscle_group: taxonomy_choice(row[:muscle_group_existing_id], row[:muscle_group_new_name]),
        confidence: row[:confidence]
      }
    end

    def taxonomy_choice(existing_id, new_name)
      return { existing_id: existing_id } if existing_id.present?
      return { new: new_name } if new_name.present?

      nil
    end
end
