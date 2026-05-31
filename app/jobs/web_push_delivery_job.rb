class WebPushDeliveryJob < ApplicationJob
  queue_as :default

  # The subscription may have been pruned (logout/unsubscribe) between enqueue
  # and run; nothing to deliver in that case.
  discard_on ActiveJob::DeserializationError

  def perform(push_subscription, title:, body: nil, path: "/")
    push_subscription.notify!(title: title, body: body, path: path)
  end
end
