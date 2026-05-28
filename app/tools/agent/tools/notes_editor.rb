module Agent
  module Tools
    # Shared surgical-edit logic for the agent's two persistent memories
    # (`Student#notes_md`, `Organization#notes_md`). Mirrors Claude Code's
    # Edit tool: `old_string` must be unique in the current content, or
    # empty when bootstrapping an empty memory. The PORO does no
    # persistence — callers decide whether to write the returned value.
    class NotesEditor
      Result = Struct.new(:value, :error, keyword_init: true) do
        def ok? = error.nil?
      end

      def self.apply(current:, old_string:, new_string:)
        current    = current.to_s
        old_string = old_string.to_s
        new_string = new_string.to_s

        if current.empty?
          return Result.new(error: "A memória está vazia; passe `old_string` vazio para inicializá-la.") unless old_string.empty?

          return Result.new(value: new_string)
        end

        return Result.new(error: "`old_string` não pode ser vazio quando há conteúdo; passe o trecho exato a substituir.") if old_string.empty?

        occurrences = current.scan(old_string).length
        return Result.new(error: "`old_string` não foi encontrado na memória atual.") if occurrences.zero?
        return Result.new(error: "`old_string` aparece #{occurrences} vezes na memória; inclua mais contexto para identificar um único trecho.") if occurrences > 1

        Result.new(value: current.sub(old_string, new_string))
      end
    end
  end
end
