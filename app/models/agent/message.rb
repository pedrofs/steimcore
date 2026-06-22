class Agent::Message < ApplicationRecord
  acts_as_message chat: :chat, chat_class: "Agent::Chat",
                  tool_calls: :tool_calls, tool_call_class: "Agent::ToolCall",
                  model: :model, model_class: "Agent::Model"

  belongs_to :trainer, class_name: "User", optional: true

  has_many_attached :attachments
  has_many_attached :voice_clips

  include Agent::Message::Transcribable

  # True when the row carries nothing a human or the model needs to see —
  # typically crash debris from a turn that errored after the gem pre-created
  # the assistant row but before any content streamed. Such rows are dropped
  # from both the LLM payload (`Agent::Chat::MessageSelection`) and the chat UI
  # without ever being deleted, so the persisted history stays intact.
  def empty_payload?
    content.to_s.strip.blank? &&
      tool_calls.none? &&
      self[:thinking_text].to_s.strip.blank? &&
      !attachments.attached? &&
      !voice_clips.attached?
  end
end
