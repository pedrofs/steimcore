import { router } from "@inertiajs/react"
import { CalendarRangeIcon, Loader2Icon } from "lucide-react"
import { useState } from "react"

import {
  PeriodizationVersionView,
  type PeriodizationVersionData,
  type PeriodizationViewScope,
} from "@/components/periodization-version-view"
import { Button } from "@/components/ui/button"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { useIsMobile } from "@/hooks/use-mobile"
import { cn } from "@/lib/utils"

type Props = {
  open: boolean
  onOpenChange: (open: boolean) => void
  version: PeriodizationVersionData | null
  scope: PeriodizationViewScope
  /**
   * Called when the user taps "Ver periodização completa" from a
   * workout-scoped drawer to escalate to the full periodization view.
   */
  onEscalateToPeriodization?: () => void
  /**
   * URL the underlying inline-edit / promotion controllers should redirect
   * back to so the chat page stays mounted instead of jumping to the
   * standalone version page. Typically `window.location.pathname` plus the
   * `open_version_id` (and `open_workout_id`) query params.
   */
  returnTo: string
}

export function ArtifactDrawer({
  open,
  onOpenChange,
  version,
  scope,
  onEscalateToPeriodization,
  returnTo,
}: Props) {
  const isMobile = useIsMobile()
  const [dirtyWorkoutName, setDirtyWorkoutName] = useState<string | null>(null)

  const workoutScope =
    scope.kind === "workout" && version
      ? version.workouts.find((w) => w.id === scope.workoutId)
      : null

  const title =
    scope.kind === "workout" && workoutScope
      ? `Treino ${workoutScope.name}`
      : "Periodização"

  const description =
    scope.kind === "workout" && workoutScope
      ? `Treino ${workoutScope.position}`
      : version
        ? version.readOnly
          ? "Versão promovida — somente leitura"
          : "Esboço — pendente de promoção"
        : null

  const promotable =
    version != null && !version.promoted && !version.readOnly &&
    version.status === "completed"

  const handlePromote = () => {
    if (!version) return
    if (dirtyWorkoutName) {
      if (
        !window.confirm(
          `Promover descartará as alterações não salvas em ${dirtyWorkoutName}. Continuar?`,
        )
      ) {
        return
      }
    }
    router.post(
      `/periodization_versions/${version.id}/promotion`,
      { return_to: returnTo },
      { preserveScroll: true, preserveState: true },
    )
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side={isMobile ? "bottom" : "right"}
        className={cn(
          "flex w-full flex-col gap-0 p-0",
          isMobile
            ? "max-h-[90dvh] rounded-t-2xl"
            : "data-[side=right]:w-[80vw] data-[side=right]:sm:max-w-[80vw]",
        )}
      >
        <SheetHeader className="border-b border-border/60 px-4 pt-4 pb-3 sm:px-6">
          <div className="flex items-start gap-3 pr-10">
            <CalendarRangeIcon
              className="mt-0.5 size-5 shrink-0 text-brand"
              aria-hidden
            />
            <div className="flex-1">
              <SheetTitle className="text-base">{title}</SheetTitle>
              {description && (
                <SheetDescription className="text-xs">
                  {description}
                </SheetDescription>
              )}
            </div>
          </div>
          {scope.kind === "workout" && onEscalateToPeriodization && version && (
            <Button
              type="button"
              variant="link"
              size="sm"
              className="-mx-1 h-7 w-fit px-1 text-xs"
              onClick={onEscalateToPeriodization}
            >
              Ver periodização completa
            </Button>
          )}
        </SheetHeader>

        <div className="flex-1 overflow-y-auto px-4 py-4 sm:px-6">
          {version == null ? (
            <DrawerLoading />
          ) : (
            <PeriodizationVersionView
              version={version}
              scope={scope}
              presentation="drawer"
              returnTo={returnTo}
              onDirtyWorkoutChange={setDirtyWorkoutName}
            />
          )}
        </div>

        {promotable && (
          <div className="border-t border-border/60 bg-background px-4 py-3 sm:px-6">
            <Button
              type="button"
              className="h-11 w-full sm:h-10"
              onClick={handlePromote}
            >
              Promover esta versão
            </Button>
          </div>
        )}
      </SheetContent>
    </Sheet>
  )
}

function DrawerLoading() {
  return (
    <div className="flex flex-col items-center gap-2 py-12 text-sm text-muted-foreground">
      <Loader2Icon className="size-5 animate-spin" aria-hidden />
      <span>Carregando…</span>
    </div>
  )
}
