class Agent::Model < ApplicationRecord
  acts_as_model chats: :chats, chat_class: "Agent::Chat"
end
