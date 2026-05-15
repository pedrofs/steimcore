# The agent that powers the per-student chat. Each invocation gets fresh
# `student`, `trainer`, and `chat` inputs; the system prompt is re-rendered
# from `app/prompts/student_agent/instructions.txt.erb` on every turn so
# tool mutations (e.g. an anamnese update) are reflected immediately in
# the next turn's context.
class StudentAgent < RubyLLM::Agent
  chat_model Agent::Chat
  model "claude-opus-4-7"
  inputs :student, :trainer, :chat

  # Force plaintext SSE responses. Net::HTTP buffers gzipped bodies fully
  # before invoking Faraday's `on_data`, which collapses the per-token
  # stream into a single callback at the end of the request — chunks then
  # appear to "arrive all at once" in the UI. Disabling Accept-Encoding
  # restores per-chunk delivery.
  headers "Accept-Encoding": "identity"

  tools do
    tool_instances = [
      Agent::Tools::UpdateAnamnesis.new(student: student, trainer: trainer),
      Agent::Tools::CreatePeriodization.new(student: student, trainer: trainer),
      Agent::Tools::UpdatePeriodization.new(student: student, trainer: trainer),
      Agent::Tools::UpdateWorkout.new(student: student, trainer: trainer)
    ]

    by_name = tool_instances.index_by(&:name)
    ar_chat = chat
    llm_chat = chat.respond_to?(:to_llm) ? chat.to_llm : chat
    pending_tool_call_id = nil

    llm_chat.before_tool_call do |tool_call|
      # Plumb the LLM's tool_call.id into each tool instance before its
      # `execute` runs. Tools that produce a `PeriodizationVersion` use this
      # to look up the corresponding `Agent::ToolCall` AR row (persisted by
      # the gem at message-save time, before this callback fires) and stamp
      # it on the version's `agent_tool_call_id` FK.
      tool = by_name[tool_call.name]
      tool.current_tool_call_llm_id = tool_call.id if tool.respond_to?(:current_tool_call_llm_id=)

      # Increment the per-turn iteration counter and raise if we've blown
      # past the ceiling. `Agent::Chat::Runnable#run_turn!` catches the
      # raise and converts it into an apology + `turn_failed` broadcast.
      ar_chat.track_tool_call_iteration! if ar_chat.respond_to?(:track_tool_call_iteration!)

      pending_tool_call_id = tool_call.id
      if ar_chat.respond_to?(:broadcast_tool_call_started!)
        ar_chat.broadcast_tool_call_started!(tool_call_id: tool_call.id, name: tool_call.name)
      end
    end

    llm_chat.after_tool_result do |result|
      if ar_chat.respond_to?(:broadcast_tool_call_completed!)
        ar_chat.broadcast_tool_call_completed!(tool_call_id: pending_tool_call_id, result: result)
      end
      pending_tool_call_id = nil
    end

    tool_instances
  end

  instructions
end
