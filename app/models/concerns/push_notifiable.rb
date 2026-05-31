# "Can receive web push notifications" trait, shared by the two authenticatable
# principals (User and StudentIdentity). Each owns the browser endpoints that
# subscribed while signed in as them, and `notify` fans a notification out to
# every one of those endpoints — one background job per subscription so a single
# dead endpoint can't hold up the rest.
module PushNotifiable
  extend ActiveSupport::Concern

  included do
    has_many :push_subscriptions, as: :authenticatable, dependent: :destroy
  end

  def notify(title:, body: nil, path: "/")
    push_subscriptions.find_each do |subscription|
      WebPushDeliveryJob.perform_later(subscription, title: title, body: body, path: path)
    end
  end
end
