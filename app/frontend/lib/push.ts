import type { WebPushConfig } from "@/types"

// Client-side Web Push registration. Pairs with the server slice:
//   - PushSubscription / ManagesPushSubscriptions  (persist the endpoint)
//   - public/service-worker.js `push` handler        (render the notification)
//
// The `webPush` shared prop carries the VAPID public key + the RESTful endpoint
// for the signed-in principal (trainer vs. student). These helpers are wired
// directly to fetch (not Inertia) because subscription happens in the
// background, outside the page-navigation lifecycle.

export function pushSupported(): boolean {
  return (
    typeof window !== "undefined" &&
    "serviceWorker" in navigator &&
    "PushManager" in window &&
    "Notification" in window
  )
}

// Converts the URL-safe base64 VAPID public key into the Uint8Array that
// `pushManager.subscribe` expects as `applicationServerKey`.
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
  const raw = window.atob(base64)
  const output = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) output[i] = raw.charCodeAt(i)
  return output
}

function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""
}

// Subscribes this browser to push and persists the endpoint server-side. Safe
// to call repeatedly — re-subscribing returns the same endpoint, which the
// controller upserts. Returns false when unsupported, key missing, or the user
// denied the Notification permission.
export async function subscribeToPush(config: WebPushConfig): Promise<boolean> {
  if (!pushSupported() || !config.vapidPublicKey) return false

  const permission = await Notification.requestPermission()
  if (permission !== "granted") return false

  const registration = await navigator.serviceWorker.ready

  const subscription =
    (await registration.pushManager.getSubscription()) ??
    (await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(config.vapidPublicKey),
    }))

  const payload = subscription.toJSON()
  const keys = payload.keys ?? {}

  const response = await fetch(config.subscriptionPath, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken(),
    },
    credentials: "same-origin",
    body: JSON.stringify({
      push_subscription: {
        endpoint: payload.endpoint,
        p256dh_key: keys.p256dh,
        auth_key: keys.auth,
      },
    }),
  })

  return response.ok
}

// Removes this browser's subscription both server-side and locally. Call on
// logout or when the user opts out of notifications.
export async function unsubscribeFromPush(config: WebPushConfig): Promise<void> {
  if (!pushSupported()) return

  const registration = await navigator.serviceWorker.ready
  const subscription = await registration.pushManager.getSubscription()
  if (!subscription) return

  await fetch(`${config.subscriptionPath}?endpoint=${encodeURIComponent(subscription.endpoint)}`, {
    method: "DELETE",
    headers: { "X-CSRF-Token": csrfToken() },
    credentials: "same-origin",
  })

  await subscription.unsubscribe()
}
