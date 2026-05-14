class Agent::ChatChannel < ApplicationCable::Channel
  def subscribed
    chat = Agent::Chat.find_by(id: params[:chat_id])
    return reject if chat.nil?
    return reject unless current_user&.organization_id == chat.organization_id

    stream_from chat.stream_name
  end
end
