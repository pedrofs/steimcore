import { Link, router } from "@inertiajs/react"
import { PencilIcon, WandSparklesIcon } from "lucide-react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

type Workout = {
  id: string
  name: string
  position: number
  blocks: Block[]
}

type CurrentVersion = {
  id: string
  bodyMd: string
  workouts: Workout[]
}

type VersionSummary = {
  id: string
  createdAt: string
  current: boolean
  trainer: { id: string; email: string }
  transcriptExcerpt: string
  path: string
}

type Periodization = {
  id: string
  archived: boolean
  currentVersion: CurrentVersion | null
  versions: VersionSummary[]
}

type Student = { id: string; name: string }

type Props = { student: Student; periodization: Periodization }

export default function ShowPeriodization({ student, periodization }: Props) {
  const version = periodization.currentVersion

  return (
    <>
      <PageHeader>
        {periodization.archived && (
          <span className="inline-flex w-fit items-center rounded-full border border-dashed bg-muted/40 px-2 py-0.5 text-xs text-muted-foreground">
            Arquivada
          </span>
        )}
      </PageHeader>

      {version ? (
        <>
          {!periodization.archived && (
            <Button
              type="button"
              className="h-11 w-full gap-2 sm:h-10 sm:w-auto sm:self-start"
              onClick={() =>
                router.post(`/periodizations/${periodization.id}/edit`)
              }
            >
              <WandSparklesIcon className="size-4" />
              Modificar periodização
            </Button>
          )}

          <section className="flex flex-col gap-2">
            <h2 className="text-lg font-medium">Plano</h2>
            <Markdown content={version.bodyMd} placeholder="Plano sem conteúdo." />
          </section>

          <WorkoutsTabs
            workouts={version.workouts}
            archived={periodization.archived}
            versionId={version.id}
          />
        </>
      ) : (
        <p className="text-sm text-muted-foreground">
          Esta periodização ainda não tem uma versão ativa.
        </p>
      )}

      <VersionHistory versions={periodization.versions} />

      <div className="flex justify-start">
        <Button asChild variant="outline" className="h-11 sm:h-10">
          <Link href={`/students/${student.id}`}>Voltar ao aluno</Link>
        </Button>
      </div>
    </>
  )
}

function WorkoutsTabs({
  workouts,
  archived,
  versionId,
}: {
  workouts: Workout[]
  archived: boolean
  versionId: string
}) {
  if (workouts.length === 0) {
    return (
      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-medium">Treinos</h2>
        <p className="text-sm text-muted-foreground">
          Nenhum treino registrado.
        </p>
      </section>
    )
  }

  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Treinos</h2>
      <Tabs defaultValue={workouts[0].id}>
        <TabsList className="flex w-full flex-wrap justify-start gap-1">
          {workouts.map((w) => (
            <TabsTrigger key={w.id} value={w.id}>
              {w.name}
            </TabsTrigger>
          ))}
        </TabsList>
        {workouts.map((w) => (
          <TabsContent key={w.id} value={w.id} className="flex flex-col gap-3">
            <BlocksRenderer
              blocks={w.blocks}
              emptyPlaceholder="Treino sem conteúdo."
            />
            {!archived && (
              <Button
                type="button"
                variant="outline"
                className="mt-1 h-11 w-full gap-2 sm:h-10 sm:w-auto sm:self-end"
                onClick={() =>
                  router.post(
                    `/periodization_versions/${versionId}/workouts/${w.id}/edit`,
                  )
                }
              >
                <PencilIcon className="size-4" />
                Editar este treino
              </Button>
            )}
          </TabsContent>
        ))}
      </Tabs>
    </section>
  )
}

function VersionHistory({ versions }: { versions: VersionSummary[] }) {
  if (versions.length === 0) {
    return null
  }
  const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
  })
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Histórico de versões</h2>
      <ol className="flex flex-col gap-2">
        {versions.map((v) => (
          <li
            key={v.id}
            className={
              "flex flex-col gap-1 rounded-xl border p-3 " +
              (v.current ? "border-primary bg-primary/5" : "bg-muted/20")
            }
          >
            <div className="flex flex-wrap items-center gap-2 text-sm">
              <span className="font-medium">
                {dateFormatter.format(new Date(v.createdAt))}
              </span>
              <span className="text-muted-foreground">·</span>
              <span className="text-muted-foreground">{v.trainer.email}</span>
              {v.current && (
                <span className="ml-auto rounded-full bg-primary px-2 py-0.5 text-xs font-medium text-primary-foreground">
                  Atual
                </span>
              )}
            </div>
            {v.transcriptExcerpt.length > 0 && (
              <p className="text-sm text-muted-foreground italic">
                "{v.transcriptExcerpt}"
              </p>
            )}
            <div>
              <Link
                href={v.path}
                className="text-sm font-medium text-primary underline-offset-4 hover:underline"
              >
                Ver versão
              </Link>
            </div>
          </li>
        ))}
      </ol>
    </section>
  )
}
