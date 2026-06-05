import { useForm, usePage } from "@inertiajs/react"
import { CameraIcon, Loader2Icon, VideoIcon } from "lucide-react"
import { useRef, useState } from "react"

import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { uploadDirect } from "@/lib/direct-upload"

type QueueItem = {
  id: string
  name: string
  family: string | null
  muscleGroup: string | null
  usageCount: number
}

type Props = {
  exercises: QueueItem[]
}

export default function Show({ exercises }: Props) {
  const { flash } = usePage().props

  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Exercícios sem mídia, dos mais usados aos menos. Filme ou fotografe
          direto do celular — cada envio enriquece o exercício e o tira da fila.
        </p>
      </PageHeader>

      {flash.notice && (
        <p className="rounded-xl border border-primary/30 bg-primary/5 p-3 text-sm text-foreground">
          {flash.notice}
        </p>
      )}

      {exercises.length === 0 ? (
        <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
          Tudo filmado 🎉 Nenhum exercício usado está sem mídia. Novos itens
          aparecem aqui conforme a IA gera periodizações.
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {exercises.map((exercise) => (
            <QueueCard key={exercise.id} exercise={exercise} />
          ))}
        </ul>
      )}
    </>
  )
}

type Phase =
  | { kind: "idle" }
  | { kind: "uploading"; pct: number }
  | { kind: "saving" }

function QueueCard({ exercise }: { exercise: QueueItem }) {
  const videoInput = useRef<HTMLInputElement>(null)
  const photoInput = useRef<HTMLInputElement>(null)
  const [phase, setPhase] = useState<Phase>({ kind: "idle" })
  const form = useForm<{ media: string }>({ media: "" })
  const busy = phase.kind !== "idle"

  const handleFile = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    event.target.value = "" // let the trainer re-pick the same file after a failure
    if (!file) return

    setPhase({ kind: "uploading", pct: 0 })
    try {
      const signedId = await uploadDirect(file, (pct) =>
        setPhase({ kind: "uploading", pct }),
      )
      setPhase({ kind: "saving" })
      form.transform(() => ({ media: signedId }))
      // On success Inertia follows the redirect back to the queue and this card
      // unmounts; only the failure path needs to reset the button.
      form.post(`/exercises/${exercise.id}/media`, {
        onError: () => setPhase({ kind: "idle" }),
      })
    } catch {
      setPhase({ kind: "idle" })
    }
  }

  return (
    <li className="flex flex-col gap-3 rounded-xl border bg-card p-4">
      <div className="flex items-start justify-between gap-2">
        <span className="text-base font-medium">{exercise.name}</span>
        <Badge variant="secondary" className="shrink-0 font-normal">
          usado {exercise.usageCount}×
        </Badge>
      </div>
      <span className="text-sm text-muted-foreground">
        {summaryLine(exercise)}
      </span>

      <input
        ref={videoInput}
        type="file"
        accept="video/*"
        capture="environment"
        hidden
        onChange={handleFile}
      />
      <input
        ref={photoInput}
        type="file"
        accept="image/*"
        capture="environment"
        hidden
        onChange={handleFile}
      />

      {phase.kind === "uploading" ? (
        <div className="flex flex-col gap-1.5">
          <Progress value={phase.pct} />
          <span className="text-xs text-muted-foreground">
            Enviando… {phase.pct}%
          </span>
        </div>
      ) : phase.kind === "saving" ? (
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2Icon className="size-4 animate-spin" />
          Salvando…
        </div>
      ) : (
        <div className="flex gap-2">
          <Button
            type="button"
            onClick={() => videoInput.current?.click()}
            disabled={busy}
            className="h-11 flex-1 sm:h-10"
          >
            <VideoIcon className="size-4" />
            Filmar
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={() => photoInput.current?.click()}
            disabled={busy}
            className="h-11 flex-1 sm:h-10"
          >
            <CameraIcon className="size-4" />
            Foto
          </Button>
        </div>
      )}
    </li>
  )
}

function summaryLine(exercise: QueueItem): string {
  const parts: string[] = []
  if (exercise.family) parts.push(exercise.family)
  if (exercise.muscleGroup) parts.push(exercise.muscleGroup)
  return parts.length > 0 ? parts.join(" · ") : "Sem classificação"
}
