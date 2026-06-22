import { Link, usePage } from "@inertiajs/react"

import { cn } from "@/lib/utils"

// Route-based tabs for the Analytics section. Each tab is its own page/route, so
// these are Inertia links (not stateful Radix tabs); the active one is derived from
// the current URL. Styled to match the shadcn TabsList look.
const TABS = [
  { label: "Atividade", href: "/analytics/activity" },
  { label: "Uso dos alunos", href: "/analytics/usage" },
]

export function AnalyticsTabs() {
  const { url } = usePage()

  return (
    <div className="bg-muted text-muted-foreground inline-flex h-9 w-fit items-center justify-center rounded-lg p-[3px]">
      {TABS.map((tab) => {
        const active = url.startsWith(tab.href)
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={cn(
              "inline-flex h-[calc(100%-1px)] items-center justify-center rounded-md border border-transparent px-3 py-1 text-sm font-medium whitespace-nowrap transition-colors",
              active
                ? "bg-background text-foreground shadow-sm"
                : "hover:text-foreground",
            )}
          >
            {tab.label}
          </Link>
        )
      })}
    </div>
  )
}
