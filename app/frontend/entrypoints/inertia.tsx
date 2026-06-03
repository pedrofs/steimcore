import { createInertiaApp } from '@inertiajs/react'
import { BRAND_NAME } from '@/lib/brand'
import { initKeyboardTracking } from '@/lib/keyboard'
import { TooltipProvider } from '@/components/ui/tooltip'
import { ApplicationLayout } from '@/layouts/application-layout'
import { StudentLayout } from '@/layouts/student-layout'

initKeyboardTracking()

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    void navigator.serviceWorker.register("/service-worker.js").catch(() => {
      // PWA install is progressive enhancement; ignore registration failures.
    })
  })
}

const isUnchromed = (name: string) =>
  name === "home/landing" ||
  name === "students/agent_chats/show" ||
  name.startsWith("sessions/") ||
  name.startsWith("passwords/") ||
  name.startsWith("prototypes/") ||
  name.startsWith("training_sessions/") ||
  name.startsWith("students/periodizations/printables/")

// Authenticated student app pages get the mobile bottom-nav StudentLayout.
// Student auth/onboarding pages (sign in, password reset, profile selection,
// no-profile) are full-screen centered and stay chrome-less. Neither should
// ever render the trainer's AppSidebar.
const isStudentApp = (name: string) =>
  name === "student/home/show" ||
  name === "student/workouts/index" ||
  name === "student/medals/index"

const resolveLayout = (name: string) => {
  if (isStudentApp(name)) return StudentLayout
  if (name.startsWith("student/")) return undefined
  return isUnchromed(name) ? undefined : ApplicationLayout
}

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

  layout: (name) => resolveLayout(name),

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
