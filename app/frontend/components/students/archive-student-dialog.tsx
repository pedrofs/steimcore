import { useEffect, useState } from "react"
import { useForm } from "@inertiajs/react"

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { cn } from "@/lib/utils"

type Student = {
  id: string
  name: string
}

type Props = {
  student: Student | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

const PRESETS = [
  { value: "so_crossfit", label: "Só faz crossfit (sem musculação)" },
  { value: "stopped", label: "Parou de treinar" },
  { value: "changed_gym", label: "Mudou de academia" },
  { value: "other", label: "Outro" },
] as const

type PresetValue = (typeof PRESETS)[number]["value"]

export function ArchiveStudentDialog({ student, open, onOpenChange }: Props) {
  const [selected, setSelected] = useState<PresetValue>("so_crossfit")
  const [customReason, setCustomReason] = useState("")

  const form = useForm({ reason: "" })

  useEffect(() => {
    if (open) {
      setSelected("so_crossfit")
      setCustomReason("")
      form.clearErrors()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  if (!student) return null

  const resolvedReason =
    selected === "other"
      ? customReason.trim()
      : (PRESETS.find((p) => p.value === selected)?.label ?? "")

  const canSubmit =
    selected !== "other" || customReason.trim().length > 0

  const submit = (event: React.MouseEvent) => {
    event.preventDefault()
    form.transform(() => ({ reason: resolvedReason }))
    form.post(`/students/${student.id}/archive`, {
      preserveScroll: true,
      onSuccess: () => onOpenChange(false),
    })
  }

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Arquivar {student.name}?</AlertDialogTitle>
          <AlertDialogDescription>
            O aluno será ocultado da lista ativa. Você pode restaurá-lo a
            qualquer momento.
          </AlertDialogDescription>
        </AlertDialogHeader>

        <div
          role="radiogroup"
          aria-label="Motivo do arquivamento"
          className="flex flex-col gap-2"
        >
          {PRESETS.map((preset) => {
            const id = `archive-reason-${preset.value}`
            const isActive = selected === preset.value
            return (
              <label
                key={preset.value}
                htmlFor={id}
                className={cn(
                  "flex cursor-pointer items-center gap-3 rounded-md border p-3 text-sm transition-colors",
                  isActive
                    ? "border-foreground/40 bg-muted"
                    : "border-input hover:bg-muted/40"
                )}
              >
                <input
                  type="radio"
                  id={id}
                  name="archive-reason"
                  value={preset.value}
                  checked={isActive}
                  onChange={() => setSelected(preset.value)}
                  className="size-4 accent-foreground"
                />
                <span>{preset.label}</span>
              </label>
            )
          })}

          {selected === "other" && (
            <div className="flex flex-col gap-1.5 pt-1">
              <Label htmlFor="archive-reason-custom">Qual o motivo?</Label>
              <Input
                id="archive-reason-custom"
                value={customReason}
                onChange={(e) => setCustomReason(e.target.value)}
                placeholder="Descreva em poucas palavras"
                autoFocus
                maxLength={120}
              />
            </div>
          )}
        </div>

        <AlertDialogFooter>
          <AlertDialogCancel disabled={form.processing}>
            Cancelar
          </AlertDialogCancel>
          <AlertDialogAction
            variant="destructive"
            onClick={submit}
            disabled={!canSubmit || form.processing}
          >
            Arquivar
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
