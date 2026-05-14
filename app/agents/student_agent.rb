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
    [
      Agent::Tools::UpdateAnamnesis.new(student: student, trainer: trainer)
    ]
  end

  instructions
end
