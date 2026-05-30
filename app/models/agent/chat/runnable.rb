module Agent::Chat::Runnable
  extend ActiveSupport::Concern

  MAX_ITERATIONS = 10

  STREAM_PREFIX = "agent_chat".freeze

  ORPHAN_TOOL_RESULT_NOTICE = "Tool execution did not complete.".freeze

  # Drives a single agent turn for this chat. Called from `Agent::RunTurnJob`.
  # The user message is assumed to be persisted already; this method
  # instantiates the agent, runs `complete` with a streaming block, and
  # broadcasts events at every observable boundary (chunk, tool call started,
  # tool call completed, turn completed/failed).
  #
  # `ensure` always sets `state = :idle` so a worker crash mid-turn can't
  # leave a chat stuck in `running` forever.
  def run_turn!
    @_turn_iteration_count = 0
    heal_history!

    latest_user = messages.where(role: :user).order(:created_at).last
    latest_user&.transcribe_voice_clips!

    StudentAgent.new(chat: self, student: chattable, trainer: latest_user&.trainer)
                .complete { |chunk| broadcast_chunk!(chunk) }

    broadcast_turn_completed!(message_id: latest_assistant_message_id)
  rescue Agent::MaxIterationsExceeded
    apology = messages.create!(
      role: :assistant,
      content: "Desculpe, não consegui completar a operação."
    )
    broadcast_turn_failed!(error: "Limite de iterações excedido.")
    apology
  rescue StandardError => e
    broadcast_turn_failed!(error: friendly_error_for(e))
    raise
  ensure
    update!(state: :idle) if persisted?
  end

  # Called by `StudentAgent`'s before_tool_call hook (per turn). Increments
  # the iteration counter and raises `Agent::MaxIterationsExceeded` past the
  # ceiling so `run_turn!` can convert the failure into an apology message.
  def track_tool_call_iteration!
    @_turn_iteration_count = (@_turn_iteration_count || 0) + 1
    raise Agent::MaxIterationsExceeded if @_turn_iteration_count > MAX_ITERATIONS
  end

  def broadcast_chunk!(chunk)
    delta = chunk.respond_to?(:content) ? chunk.content.to_s : chunk.to_s
    return if delta.empty?

    broadcast!(
      type: "chunk",
      message_id: current_assistant_message_id,
      delta: delta
    )
  end

  def broadcast_tool_call_started!(tool_call_id:, name:, message_id: nil)
    broadcast!(
      type: "tool_call_started",
      message_id: message_id || current_assistant_message_id,
      tool_call_id: tool_call_id,
      name: name
    )
  end

  def broadcast_tool_call_completed!(tool_call_id:, result:)
    broadcast!(
      type: "tool_call_completed",
      tool_call_id: tool_call_id,
      result: result
    )
  end

  def broadcast_turn_completed!(message_id:)
    broadcast!(type: "turn_completed", message_id: message_id)
  end

  def broadcast_turn_failed!(error:)
    broadcast!(type: "turn_failed", error: error)
  end

  def stream_name
    "#{STREAM_PREFIX}:#{id}"
  end

  # Repairs structural defects a prior failed turn may have left in the
  # message history. Anthropic returns "Invalid request - please check your
  # input" for any of: an assistant `tool_use` block without a matching
  # `tool_result`, a content block (user OR assistant) that is empty, or two
  # consecutive messages with the same role. `run_turn!` returns the chat to
  # `:idle` via `ensure` on failure, which lets the trainer keep typing and
  # stack more `user` rows, and can leave the gem's pre-stream assistant row
  # at length 0 if the post-tool-call API call errors before any chunk
  # arrives; without a heal pass the next replay stays broken forever.
  def heal_history!
    transaction do
      heal_orphan_tool_calls!
      heal_empty_assistant_messages!
      heal_empty_user_messages!
      heal_consecutive_assistant_messages!
      heal_consecutive_user_messages!
    end
  end

  private
    def broadcast!(payload)
      ActionCable.server.broadcast(stream_name, payload)
    end

    def friendly_error_for(e)
      case e
      when RubyLLM::UnsupportedAttachmentError
        "Tipo de anexo não suportado pelo assistente."
      else
        e.message
      end
    end

    # The gem's persistence callbacks set `@message` on this AR record at the
    # start of each assistant response (see `RubyLLM::ActiveRecord::ChatMethods
    # #persist_new_message`). Reading it here lets each chunk reference the
    # message it belongs to without an extra query.
    def current_assistant_message_id
      instance_variable_get(:@message)&.id
    end

    def latest_assistant_message_id
      current_assistant_message_id ||
        messages.where(role: :assistant).order(:created_at).pluck(:id).last
    end

    def heal_orphan_tool_calls!
      messages.where(role: "assistant").includes(:tool_calls).to_a.each do |assistant|
        assistant.tool_calls.each do |tc|
          next if tc.result_message
          messages.create!(role: "tool", tool_call_id: tc.id, content: ORPHAN_TOOL_RESULT_NOTICE)
        end
      end
    end

    def heal_empty_user_messages!
      messages.where(role: "user").to_a.each do |m|
        next if m.content.to_s.strip.present?
        next if m.attachments.attached?
        next if m.voice_clips.attached?
        m.destroy
      end
    end

    # The gem persists the assistant row at the start of streaming and fills
    # `content` as chunks arrive. If the API call errors before any chunk
    # streams, the row stays at length 0. Anthropic rejects empty text blocks
    # on replay. Drop only rows that carry no information at all — assistants
    # that hold `tool_calls` or `thinking_text` still need to be sent.
    def heal_empty_assistant_messages!
      messages.where(role: "assistant").to_a.each do |m|
        next if m.content.to_s.strip.present?
        next if m.tool_calls.any?
        next if m[:thinking_text].to_s.strip.present?
        m.destroy
      end
    end

    # Symmetric to the user coalesce, but only safe for runs of text-only
    # assistants. An assistant with `tool_calls` can't be naively concatenated
    # — the tool_use blocks have to stay in their original message structure
    # so the paired `tool_result` resolves — so we bail out of any run that
    # touches a tool-bearing assistant and leave it to a higher-level fix.
    def heal_consecutive_assistant_messages!
      ordered = messages.order(:created_at, :id).to_a
      current = []
      ordered.each do |m|
        if m.role.to_s == "assistant"
          current << m
        else
          coalesce_assistant_run!(current) if current.size > 1
          current = []
        end
      end
      coalesce_assistant_run!(current) if current.size > 1
    end

    def coalesce_assistant_run!(run)
      return if run.any? { |m| m.tool_calls.any? }

      keeper = run.last
      earlier = run[0..-2]
      parts = run.map { |m| m.content.to_s.strip }.reject(&:empty?)

      keeper.update!(content: parts.join("\n\n"))
      earlier.each(&:destroy)
    end

    def heal_consecutive_user_messages!
      ordered = messages.order(:created_at, :id).to_a
      current = []
      ordered.each do |m|
        if m.role.to_s == "user"
          current << m
        else
          coalesce_user_run!(current) if current.size > 1
          current = []
        end
      end
      coalesce_user_run!(current) if current.size > 1
    end

    # Merges a run of consecutive user messages into the latest one: text is
    # concatenated chronologically, attachments and voice clips are re-attached
    # to the keeper (so audio that hasn't been transcribed yet still has a
    # chance to be picked up by `transcribe_voice_clips!` below), then the
    # earlier rows are destroyed.
    def coalesce_user_run!(run)
      keeper = run.last
      earlier = run[0..-2]
      parts = run.map { |m| m.content.to_s.strip }.reject(&:empty?)

      earlier.each do |m|
        if m.attachments.attached?
          m.attachments.attachments.each { |att| keeper.attachments.attach(att.blob) }
        end
        if m.voice_clips.attached?
          m.voice_clips.attachments.each { |att| keeper.voice_clips.attach(att.blob) }
        end
      end

      keeper.update!(content: parts.join("\n\n"))
      earlier.each(&:destroy)
    end
end
