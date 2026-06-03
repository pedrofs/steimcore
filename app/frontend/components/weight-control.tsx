import { DumbbellIcon } from "lucide-react"
import { useEffect, useState } from "react"

import { Button } from "@/components/ui/button"
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

// Inline weight affordance for a single movement (an exercise block or a group
// item). Renders a tappable pill showing the current load, and a bottom Drawer
// to edit it. The weight is free-form text the trainer/student defines during a
// live session; it persists per movement and shows up in future sessions.
//
// The pill stops click propagation so tapping it never toggles the surrounding
// "block done" card. `open`/`onOpenChange` are optional — pass them to drive the
// drawer from elsewhere (e.g. a swipe action); otherwise it self-manages.
export function WeightControl({
  exerciseName,
  weight,
  disabled = false,
  onSubmit,
  open: openProp,
  onOpenChange,
  className,
}: {
  exerciseName: string
  weight?: string | null
  disabled?: boolean
  onSubmit: (value: string) => void
  open?: boolean
  onOpenChange?: (next: boolean) => void
  className?: string
}) {
  const [internalOpen, setInternalOpen] = useState(false)
  const open = openProp ?? internalOpen
  const setOpen = onOpenChange ?? setInternalOpen
  const [value, setValue] = useState(weight ?? "")

  // Re-seed the field from the latest saved value each time the drawer opens.
  useEffect(() => {
    if (open) setValue(weight ?? "")
  }, [open, weight])

  function submit() {
    const trimmed = value.trim()
    if (!trimmed) return
    onSubmit(trimmed)
    setOpen(false)
  }

  return (
    <>
      <span
        role="button"
        tabIndex={disabled ? -1 : 0}
        aria-disabled={disabled}
        aria-label={
          weight ? `Carga: ${weight}. Editar.` : `Definir carga de ${exerciseName}`
        }
        onClick={(event) => {
          event.stopPropagation()
          if (!disabled) setOpen(true)
        }}
        onKeyDown={(event) => {
          if (disabled) return
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault()
            event.stopPropagation()
            setOpen(true)
          }
        }}
        className={cn(
          "inline-flex shrink-0 items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium tabular-nums transition-colors",
          weight
            ? "border-brand/30 bg-brand/10 text-brand"
            : "border-dashed border-muted-foreground/40 text-muted-foreground",
          !disabled && "cursor-pointer hover:border-foreground/30",
          className,
        )}
      >
        <DumbbellIcon className="size-3" />
        {weight || "Carga"}
      </span>

      <Drawer open={open} onOpenChange={setOpen}>
        <DrawerContent>
          <DrawerHeader>
            <DrawerTitle className="truncate">Carga · {exerciseName}</DrawerTitle>
          </DrawerHeader>
          <div className="px-4">
            <Input
              autoFocus
              value={value}
              onChange={(event) => setValue(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") submit()
              }}
              placeholder="ex: 60kg, 20kg/lado, peso do corpo"
              aria-label="Carga"
            />
            <p className="mt-2 text-xs text-muted-foreground">
              Texto livre. Fica salvo para as próximas sessões.
            </p>
          </div>
          <DrawerFooter>
            <Button onClick={submit} disabled={!value.trim()}>
              Salvar
            </Button>
            <DrawerClose asChild>
              <Button variant="ghost">Cancelar</Button>
            </DrawerClose>
          </DrawerFooter>
        </DrawerContent>
      </Drawer>
    </>
  )
}
