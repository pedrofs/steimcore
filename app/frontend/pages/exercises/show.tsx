import { Link } from "@inertiajs/react"
import { ImageIcon, PencilIcon } from "lucide-react"

import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

type Media = {
  id: string
  filename: string
  contentType: string | null
  url: string
  isVideo: boolean
}

type Exercise = {
  id: string
  name: string
  family: string | null
  muscleGroup: string | null
  state: "unenriched" | "enriched"
  aliases: Array<{ rawName: string; source: string }>
  media: Media[]
}

type Props = {
  exercise: Exercise
}

export default function Show({ exercise }: Props) {
  return (
    <>
      <PageHeader
        actions={
          <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
            <Link href={`/exercises/${exercise.id}/edit`}>
              <PencilIcon className="size-4" />
              Enriquecer
            </Link>
          </Button>
        }
      >
        <div className="flex items-center gap-2">
          {exercise.state === "enriched" ? (
            <Badge variant="default">
              <ImageIcon className="size-3" />
              Enriquecido
            </Badge>
          ) : (
            <Badge variant="outline">Sem mídia</Badge>
          )}
        </div>
      </PageHeader>

      <dl className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="Família" value={exercise.family} />
        <Field label="Grupo muscular" value={exercise.muscleGroup} />
      </dl>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">Mídia</h2>
        {exercise.media.length === 0 ? (
          <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
            Nenhuma mídia anexada. Adicione uma foto ou vídeo para enriquecer
            este exercício.
          </p>
        ) : (
          <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {exercise.media.map((item) => (
              <li
                key={item.id}
                className="overflow-hidden rounded-xl border bg-card"
              >
                {item.isVideo ? (
                  <video
                    src={item.url}
                    controls
                    className="aspect-square w-full object-cover"
                  />
                ) : (
                  <img
                    src={item.url}
                    alt={item.filename}
                    className="aspect-square w-full object-cover"
                  />
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">
          Nomes ({exercise.aliases.length})
        </h2>
        <ul className="flex flex-wrap gap-2">
          {exercise.aliases.map((alias) => (
            <li key={`${alias.rawName}-${alias.source}`}>
              <Badge variant="secondary" className="font-normal">
                {alias.rawName}
              </Badge>
            </li>
          ))}
        </ul>
      </section>
    </>
  )
}

function Field({ label, value }: { label: string; value: string | null }) {
  return (
    <div className="flex flex-col gap-1 rounded-xl border bg-card p-4">
      <dt className="text-sm text-muted-foreground">{label}</dt>
      <dd className="text-base font-medium">{value ?? "—"}</dd>
    </div>
  )
}
