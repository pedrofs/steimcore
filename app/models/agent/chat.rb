# Per-chattable conversation between a trainer and the assistant. Wraps the
# RubyLLM Rails integration: a chat owns ordered messages, persists tool
# calls, and tracks whether a turn is currently in flight via the `state`
# column. v1 chats are always attached to a Student via the polymorphic
# `chattable` association; the polymorphic shape keeps the option open for
# future chattable types without a column rename.
class Agent::Chat < ApplicationRecord
  acts_as_chat messages: :messages, message_class: "Agent::Message",
               model: :model, model_class: "Agent::Model"

  belongs_to :organization
  belongs_to :chattable, polymorphic: true

  enum :state, { idle: "idle", running: "running" }, validate: true
end
