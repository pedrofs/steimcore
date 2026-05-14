class Agent::ToolCall < ApplicationRecord
  acts_as_tool_call message: :message, message_class: "Agent::Message",
                    result: :result_message, result_class: "Agent::Message"
end
