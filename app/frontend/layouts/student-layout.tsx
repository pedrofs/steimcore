import { Head, Link, router, usePage } from "@inertiajs/react"
import { DumbbellIcon, HomeIcon, LogOut, Repeat2, UserRound } from "lucide-react"
import { type ReactNode, useState } from "react"

import { BrandMark } from "@/components/brand"
import { InertiaProgressBar } from "@/components/inertia-progress"
import { PullToRefresh } from "@/components/pull-to-refresh"
import { Button } from "@/components/ui/button"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"

// Authenticated student shell. Replaces the trainer's collapsible AppSidebar
// (which reads a trainer User and isn't student-aware) with a mobile-first
// bottom nav. Applied via the layout resolver in entrypoints/inertia.tsx for
// student app pages; the auth/onboarding student pages stay chrome-less.
export function StudentLayout({ children }: { children: ReactNode }) {
  const { props, url } = usePage()
  const title = props.title

  return (
    <div className="relative flex min-h-dvh flex-col bg-background">
      <Head title={title ?? undefined} />
      <InertiaProgressBar />
      <PullToRefresh />
      {/* No top safe-area spacer: student app pages own their header and bleed
          it into the status-bar area (see the dashboard hero). */}
      <main className="flex-1 pb-[calc(5.25rem+env(safe-area-inset-bottom))]">
        {children}
      </main>
      <StudentBottomNav currentUrl={url} />
    </div>
  )
}

function StudentBottomNav({ currentUrl }: { currentUrl: string }) {
  const [accountOpen, setAccountOpen] = useState(false)
  const homeActive = currentUrl.startsWith("/student/home")
  const workoutsActive = currentUrl.startsWith("/student/workouts")

  return (
    <>
      <nav
        aria-label="Navegação"
        className="fixed inset-x-0 bottom-0 z-40 border-t border-border/70 bg-background/85 backdrop-blur-lg"
      >
        <div className="mx-auto grid max-w-md grid-cols-3 px-2 pt-1.5 pb-[calc(0.5rem+env(safe-area-inset-bottom))]">
          <NavTab
            label="Início"
            active={homeActive}
            icon={<HomeIcon className="size-[1.35rem]" strokeWidth={2.25} />}
            asLink
            href="/student/home"
          />
          <NavTab
            label="Treinos"
            active={workoutsActive}
            icon={<DumbbellIcon className="size-[1.35rem]" strokeWidth={2.25} />}
            asLink
            href="/student/workouts"
          />
          <NavTab
            label="Conta"
            active={accountOpen}
            icon={<UserRound className="size-[1.35rem]" strokeWidth={2.25} />}
            onClick={() => setAccountOpen(true)}
          />
        </div>
      </nav>

      <AccountSheet open={accountOpen} onOpenChange={setAccountOpen} />
    </>
  )
}

function NavTab({
  label,
  icon,
  active,
  href,
  asLink,
  onClick,
}: {
  label: string
  icon: ReactNode
  active: boolean
  href?: string
  asLink?: boolean
  onClick?: () => void
}) {
  const content = (
    <span
      className={cn(
        "flex flex-col items-center gap-1 rounded-xl py-1.5 transition-colors",
        active ? "text-brand" : "text-muted-foreground"
      )}
    >
      <span
        className={cn(
          "relative grid place-items-center transition-transform duration-200",
          active && "-translate-y-0.5"
        )}
      >
        {icon}
        {active && (
          <span className="absolute -bottom-1.5 size-1 rounded-full bg-brand" />
        )}
      </span>
      <span className="text-[0.7rem] font-medium tracking-wide">{label}</span>
    </span>
  )

  if (asLink && href) {
    return (
      <Link href={href} className="block min-h-11">
        {content}
      </Link>
    )
  }

  return (
    <button type="button" onClick={onClick} className="block min-h-11 w-full">
      {content}
    </button>
  )
}

function AccountSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { props } = usePage()
  const canSwitchProfile = props.canSwitchProfile
  const organizationName = props.currentOrganization?.name

  const signOut = () => router.delete("/student/session", { preserveScroll: true })

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="bottom"
        className="gap-0 rounded-t-3xl pb-[calc(1.25rem+env(safe-area-inset-bottom))]"
      >
        <SheetHeader className="items-center gap-3 pt-7 pb-2 text-center">
          <BrandMark tone="color" className="size-12" />
          <div className="space-y-0.5">
            <SheetTitle className="text-lg">Sua conta</SheetTitle>
            {organizationName && (
              <SheetDescription>{organizationName}</SheetDescription>
            )}
          </div>
        </SheetHeader>

        <div className="flex flex-col gap-2 p-4 pt-3">
          {canSwitchProfile && (
            <Button
              asChild
              variant="outline"
              className="h-12 justify-start gap-3 rounded-xl text-base"
            >
              <Link href="/student/profile_selection/new">
                <Repeat2 className="size-5 text-muted-foreground" />
                Trocar de perfil
              </Link>
            </Button>
          )}
          <Button
            variant="outline"
            onClick={signOut}
            className="h-12 justify-start gap-3 rounded-xl text-base text-destructive hover:text-destructive"
          >
            <LogOut className="size-5" />
            Sair
          </Button>
        </div>
      </SheetContent>
    </Sheet>
  )
}
