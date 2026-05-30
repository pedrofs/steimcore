import { createInertiaApp } from '@inertiajs/react'
import { BRAND_NAME } from '@/lib/brand'
import { TooltipProvider } from '@/components/ui/tooltip'
import { ApplicationLayout } from '@/layouts/application-layout'

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    void navigator.serviceWorker.register("/service-worker.js").catch(() => {
      // PWA install is progressive enhancement; ignore registration failures.
    })
  })
}

const isUnchromed = (name: string) =>
  name.startsWith("sessions/") ||
  name.startsWith("passwords/") ||
  name.startsWith("prototypes/") ||
  name.startsWith("training_sessions/") ||
  name.startsWith("students/periodizations/printables/")

function dismissBootSplash() {
  const splash = document.getElementById("app-boot-splash")
  if (!splash) return
  splash.classList.add("is-hidden")
  window.setTimeout(() => splash.remove(), 280)
}

void createInertiaApp({
  pages: "../pages",

  title: (title) => (title ? `${title} · ${BRAND_NAME}` : BRAND_NAME),

  strictMode: true,

  progress: false,

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => {
      return { queryStringArrayFormat: "brackets" }
    },
  },

  layout: (name) => (isUnchromed(name) ? undefined : ApplicationLayout),

  withApp: (app) => <TooltipProvider>{app}</TooltipProvider>,
}).catch((error) => {
  // This ensures this entrypoint is only loaded on Inertia pages
  // by checking for the presence of the root element (#app by default).
  // Feel free to remove this `catch` if you don't need it.
  if (document.getElementById("app")) {
    throw error
  } else {
    console.error(
      "Missing root element.\n\n" +
      "If you see this error, it probably means you loaded Inertia.js on non-Inertia pages.\n" +
      'Consider moving <%= vite_typescript_tag "inertia.tsx" %> to the Inertia-specific layout instead.',
    )
  }
}).finally(dismissBootSplash)
