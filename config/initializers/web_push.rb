# frozen_string_literal: true

# Web Push (VAPID) configuration. The VAPID keypair identifies this application
# server to the browser push services. The public key is safe to ship to the
# client (it's handed to `pushManager.subscribe`); the private key must stay
# secret and is used to sign delivery requests in `PushSubscription#notify!`.
#
# Keys are read from ENV first (production — set via .kamal/secrets), falling
# back to encrypted credentials (development holds a dev keypair). Generate a
# fresh pair with:
#
#   bin/rails runner 'k = WebPush.generate_key; puts k.public_key; puts k.private_key'
#
# When no keypair is configured, push delivery is treated as disabled rather
# than raising — the subscription endpoints stay inert so the PWA still works.
Rails.application.configure do
  credentials = Rails.application.credentials.web_push || {}

  config.x.web_push.vapid_public_key  = ENV["VAPID_PUBLIC_KEY"].presence  || credentials[:vapid_public_key]
  config.x.web_push.vapid_private_key = ENV["VAPID_PRIVATE_KEY"].presence || credentials[:vapid_private_key]
  config.x.web_push.vapid_subject     = ENV["VAPID_SUBJECT"].presence ||
                                        credentials[:vapid_subject] ||
                                        "mailto:contato@steimfit.com"
end
