module Agent
  module Tools
    # Read-only access to the agent's current memory about the ORGANIZATION
    # (`Organization#notes_md`). Exists so the agent can recover when an
    # `update_organization_notes` edit fails because its `old_string` no
    # longer matches the live memory — e.g. the system-prompt snapshot
    # drifted from what's persisted. Read the exact current content here,
    # then retry the edit with a correct `old_string`. Reloads from the
    # database so the value reflects the persisted memory, never a stale
    # in-prompt copy.
    class ReadOrganizationNotes < RubyLLM::Tool
      description <<~DESC
        Lê a memória atual do agente sobre a ORGANIZAÇÃO (`notes_md`),
        exatamente como está gravada agora. Use quando uma chamada de
        `update_organization_notes` falhar porque o `old_string` não bateu
        com o conteúdo atual: leia a memória aqui, copie o trecho exato e
        refaça a edição com um `old_string` correto. Ferramenta interna de
        leitura — não gera card nem deve ser mencionada ao treinador.
      DESC

      def name
        "read_organization_notes"
      end

      def initialize(organization:, trainer:)
        super()
        @organization = organization
        @trainer      = trainer
      end

      def execute
        { notes_md: @organization.reload.notes_md.to_s }
      end
    end
  end
end
