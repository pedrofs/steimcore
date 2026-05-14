module Agent::Chat::Runnable
  extend ActiveSupport::Concern

  MAX_ITERATIONS = 10

  STREAM_PREFIX = "agent_chat".freeze

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
    trainer = messages.where(role: :user).order(:created_at).last&.trainer
    StudentAgent.new(chat: self, student: chattable, trainer: trainer)
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
    broadcast_turn_failed!(error: e.message)
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

  private
    def broadcast!(payload)
      ActionCable.server.broadcast(stream_name, payload)
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
end
