# Read-only "prepare the payload" layer that sits between the persisted chat
# history and the LLM. RubyLLM calls `order_messages_for_llm` (see
# `RubyLLM::ActiveRecord::ChatMethods#to_llm`) with every persisted message and
# sends back whatever we return — each element just has to respond to `#to_llm`.
#
# We return a *subset of the real `Agent::Message` records*, never a rewritten
# or synthesized one, so this whole layer touches nothing in the database. The
# persisted chat stays a faithful record of what actually happened; only the
# request we ship to Anthropic is reshaped.
#
# Two concerns, both expressed purely as "keep this record or not":
#
#   heal   — make the list something Anthropic will accept:
#            • drop crash debris (an assistant row the gem pre-created at the
#              start of a turn that errored before any content streamed),
#            • drop orphan tool_use blocks (an assistant whose tool_calls have
#              no matching tool_result — Anthropic 400s on these) and any
#              tool_result whose tool_use we dropped,
#            • collapse a run of consecutive same-role messages to its last
#              record (Anthropic requires user/assistant to alternate). We do
#              NOT merge their content — a run only happens after a failed turn
#              + retype, where the latest message supersedes the earlier ones.
#
#   window — bound the payload to the most recent `MESSAGE_WINDOW` messages so
#            cost/latency don't grow without limit as a chat gets long.
#
# `include` this AFTER `acts_as_chat` so the override wins method lookup over
# the gem's default `order_messages_for_llm`.
module Agent::Chat::MessageSelection
  extend ActiveSupport::Concern

  # Most recent conversation messages to include in each API request. The
  # persisted history is never truncated — this only bounds the request.
  MESSAGE_WINDOW = 40

  # RubyLLM hook. `messages` is the full ordered history (system rows first,
  # then the conversation). We keep system rows verbatim and reshape the rest.
  def order_messages_for_llm(messages)
    system, conversation = messages.partition { |m| m.role.to_s == "system" }
    system + drop_leading_non_user(window(heal(conversation)))
  end

  # The exact list we would send right now. Handy from a console or a test, and
  # cheap enough to log when a turn fails (the DB no longer shows "what we
  # sent", since the payload is computed rather than stored).
  def messages_for_llm
    order_messages_for_llm(messages.order(:created_at, :id).to_a)
  end

  private
    def heal(messages)
      messages = messages.reject { |m| debris?(m) }
      messages = drop_unpaired_tool_messages(messages)
      collapse_consecutive_roles(messages)
    end

    # Crash debris: a user/assistant row that carries nothing the model needs.
    # Tool rows are never dropped here — an empty-bodied tool_result is still a
    # required half of a tool_use/tool_result pair.
    def debris?(message)
      role = message.role.to_s
      (role == "user" || role == "assistant") && message.empty_payload?
    end

    # Anthropic rejects an assistant `tool_use` block with no matching
    # `tool_result`, and a `tool_result` with no preceding `tool_use`. Keep only
    # complete pairs: drop an assistant whose tool_calls aren't all answered,
    # then drop any tool_result whose owning assistant is no longer present.
    def drop_unpaired_tool_messages(messages)
      answered = messages.select { |m| m.role.to_s == "tool" }
                         .filter_map { |m| m.tool_call_id }
                         .to_set

      kept = messages.reject do |m|
        next false unless m.role.to_s == "assistant"
        tool_calls = m.tool_calls.to_a
        tool_calls.any? && tool_calls.any? { |tc| answered.exclude?(tc.id) }
      end

      live_tool_call_ids = kept.select { |m| m.role.to_s == "assistant" }
                               .flat_map { |m| m.tool_calls.map(&:id) }
                               .to_set

      kept.reject { |m| m.role.to_s == "tool" && live_tool_call_ids.exclude?(m.tool_call_id) }
    end

    # Collapse a maximal run of same-role messages to its last record. Only
    # `user`/`assistant` roles alternate in Anthropic's view; consecutive
    # `tool` rows (one per tool_call in a single assistant turn) are legitimate
    # and left alone. After `drop_unpaired_tool_messages` a tool-bearing
    # assistant is always followed by its tool_result rows, so a run of
    # assistants here is only ever plain text — selecting the last is safe.
    def collapse_consecutive_roles(messages)
      messages.each_with_object([]) do |message, kept|
        previous = kept.last
        if previous && previous.role.to_s == message.role.to_s && collapsible?(message.role)
          kept[-1] = message
        else
          kept << message
        end
      end
    end

    def collapsible?(role)
      role = role.to_s
      role == "user" || role == "assistant"
    end

    def window(messages)
      return messages if messages.size <= MESSAGE_WINDOW

      messages.last(MESSAGE_WINDOW)
    end

    # Anthropic requires the first message to be a `user` turn. After windowing
    # (or after dropping a leading empty/orphan row) the slice can start on an
    # assistant or tool row; trim until the first user message.
    def drop_leading_non_user(messages)
      first_user = messages.index { |m| m.role.to_s == "user" }
      first_user ? messages.drop(first_user) : []
    end
end
