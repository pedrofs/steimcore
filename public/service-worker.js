self.addEventListener("install", () => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener("fetch", () => {
  // Pass-through. Required for PWA installability; no caching strategy applied.
})

// Web Push: render the notification pushed by PushSubscription#notify!. The
// payload shape ({ title, options }) is produced server-side in
// PushSubscription::Deliverable#notification_payload.
self.addEventListener("push", (event) => {
  if (!event.data) return

  let payload
  try {
    payload = event.data.json()
  } catch {
    payload = { title: event.data.text(), options: {} }
  }

  const { title, options } = payload
  event.waitUntil(self.registration.showNotification(title, options || {}))
})

// Focus an existing tab on the target path if one is open, otherwise open a new
// window. The path travels in options.data.path (see the server payload).
self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const path = (event.notification.data && event.notification.data.path) || "/"

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (new URL(client.url).pathname === path && "focus" in client) {
          return client.focus()
        }
      }

      if (self.clients.openWindow) {
        return self.clients.openWindow(path)
      }
    })
  )
})
