module Agent
  module Tools
    # Shared helpers for the periodization-touching tools. Single source of
    # truth for the bits of metadata that surface in tool result payloads
    # (and downstream in the chat cards).
    module PeriodizationToolHelpers
      module_function

      # 1-indexed sequence number of the given version within its
      # periodization, ordered by creation. The first version is 1, the
      # next fork is 2, etc. Mirrors how a trainer would refer to "versão
      # 1" / "versão 2" in conversation.
      def version_number(version)
        version.periodization.versions.order(:created_at, :id).pluck(:id).index(version.id).then do |idx|
          idx.nil? ? nil : idx + 1
        end
      end

      # The version the agent currently considers "the working draft":
      # the most recently created version of the periodization. If that
      # version is `read_only?` (the trainer promoted it), the agent forks
      # a new version off of it; otherwise it mutates in place. Using the
      # latest version — rather than `periodization.current_version` —
      # lets the agent edit drafts before they are formally promoted.
      def latest_version(periodization)
        periodization.versions.order(:created_at, :id).last
      end
    end
  end
end
