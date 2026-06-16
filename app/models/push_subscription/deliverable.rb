# Delivery slice for a single browser push endpoint. Owns the VAPID-signed
# `WebPush.payload_send` call and the self-pruning that keeps the table free of
# dead endpoints: when a push service reports the subscription is gone
# (404/410), the row is destroyed so we stop trying. Other transport errors are
# re-raised for the job's retry policy to handle.
module PushSubscription::Deliverable
  extend ActiveSupport::Concern

  # Shape consumed by the service worker's `push` handler:
  #   const { title, options } = await event.data.json()
  #   self.registration.showNotification(title, options)
  def notify!(title:, body: nil, path: "/", **options)
    return unless self.class.delivery_configured?

    WebPush.payload_send(
      endpoint: endpoint,
      p256dh: p256dh_key,
      auth: auth_key,
      message: notification_payload(title:, body:, path:, **options).to_json,
      vapid: self.class.vapid_identification,
      urgency: "high"
    )
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    destroy
  end

  class_methods do
    def delivery_configured?
      vapid_identification[:public_key].present? && vapid_identification[:private_key].present?
    end

    def vapid_identification
      web_push = Rails.application.config.x.web_push
      {
        subject: web_push.vapid_subject,
        public_key: web_push.vapid_public_key,
        private_key: web_push.vapid_private_key
      }
    end
  end

  private
    def notification_payload(title:, body:, path:, **options)
      {
        title: title,
        options: {
          body: body,
          icon: "/icon-192.png",
          badge: "/icon-192.png",
          data: { path: path }
        }.merge(options).compact
      }
    end
end
