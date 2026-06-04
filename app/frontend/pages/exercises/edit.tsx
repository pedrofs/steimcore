import { Form, Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

type Exercise = {
  id: string
  name: string
  family: string | null
  muscleGroup: string | null
  state: "unenriched" | "enriched"
  media: Array<{ id: string; filename: string; url: string; isVideo: boolean }>
}

type Props = {
  exercise: Exercise
}

export default function Edit({ exercise }: Props) {
  const hasMedia = exercise.media.length > 0

  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Confirme a classificação e anexe mídia. Adicionar mídia marca o
          exercício como enriquecido.
        </p>
      </PageHeader>

      <Form
        method="patch"
        action={`/exercises/${exercise.id}`}
        className="flex flex-col gap-6"
      >
        {({ errors, processing }) => (
          <>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="exercise_family_name">Família</Label>
                <Input
                  id="exercise_family_name"
                  name="exercise[exercise_family_name]"
                  defaultValue={exercise.family ?? ""}
                  className="h-11"
                  placeholder="Supino, Agachamento..."
                />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="muscle_group_name">Grupo muscular</Label>
                <Input
                  id="muscle_group_name"
                  name="exercise[muscle_group_name]"
                  defaultValue={exercise.muscleGroup ?? ""}
                  className="h-11"
                  placeholder="Peito, Quadríceps..."
                />
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <Label htmlFor="media">Mídia (foto/vídeo)</Label>
              <Input
                id="media"
                name="exercise[media][]"
                type="file"
                accept="image/*,video/*"
                multiple
                className="h-11"
              />
              {hasMedia && (
                <p className="text-sm text-muted-foreground">
                  {exercise.media.length} mídia(s) já anexada(s). Novos arquivos
                  são adicionados aos existentes.
                </p>
              )}
              {errors.media && (
                <p className="text-sm text-destructive">
                  {errors.media.join(", ")}
                </p>
              )}
            </div>

            <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
              <Button asChild variant="outline" className="h-11 sm:h-10">
                <Link href={`/exercises/${exercise.id}`}>Cancelar</Link>
              </Button>
              <Button
                type="submit"
                disabled={processing}
                className="h-11 sm:h-10"
              >
                {processing ? "Salvando..." : "Salvar"}
              </Button>
            </div>
          </>
        )}
      </Form>
    </>
  )
}
