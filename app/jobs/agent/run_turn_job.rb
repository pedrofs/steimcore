class Agent::RunTurnJob < ApplicationJob
  queue_as :default

  def perform(chat)
    chat.run_turn!
  end
end
