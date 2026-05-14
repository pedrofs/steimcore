# The agent that powers the per-student chat. Each invocation gets fresh
# `student`, `trainer`, and `chat` inputs; the system prompt is re-rendered
# from `app/prompts/student_agent/instructions.txt.erb` on every turn so
# tool mutations (e.g. an anamnese update) are reflected immediately in
# the next turn's context.
class StudentAgent < RubyLLM::Agent
  chat_model Agent::Chat
  model "claude-opus-4-7"
  inputs :student, :trainer, :chat

  tools do
    tool_instances = [
      Agent::Tools::UpdateAnamnesis.new(student: student, trainer: trainer),
      Agent::Tools::CreatePeriodization.new(student: student, trainer: trainer),
      Agent::Tools::UpdatePeriodization.new(student: student, trainer: trainer),
      Agent::Tools::UpdateWorkout.new(student: student, trainer: trainer)
    ]

    # Plumb the LLM's tool_call.id into each tool instance before its
    # `execute` runs. Tools that produce a `PeriodizationVersion` use this
    # to look up the corresponding `Agent::ToolCall` AR row (persisted by
    # the gem at message-save time, before this callback fires) and stamp
    # it on the version's `agent_tool_call_id` FK.
    by_name = tool_instances.index_by(&:name)
    llm_chat = chat.respond_to?(:to_llm) ? chat.to_llm : chat
    llm_chat.before_tool_call do |tool_call|
      tool = by_name[tool_call.name]
      tool.current_tool_call_llm_id = tool_call.id if tool.respond_to?(:current_tool_call_llm_id=)
    end

    tool_instances
  end

  instructions
end
