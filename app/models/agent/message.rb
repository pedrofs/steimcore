class Agent::Message < ApplicationRecord
  acts_as_message chat: :chat, chat_class: "Agent::Chat",
                  tool_calls: :tool_calls, tool_call_class: "Agent::ToolCall",
                  model: :model, model_class: "Agent::Model"

  belongs_to :trainer, class_name: "User", optional: true

  has_many_attached :attachments
  has_many_attached :voice_clips

  include Agent::Message::Transcribable
end
