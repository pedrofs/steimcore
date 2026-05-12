import { Link, router } from "@inertiajs/react"
import { PencilIcon, PrinterIcon } from "lucide-react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent } from "@/components/ui/tabs"
import { WorkoutsTabsList } from "@/components/workouts-tabs-list"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"

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
  draft: boolean
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
  const printablePath = `/students/${student.id}/periodization/printable`

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
            <div className="no-print flex flex-col gap-2 sm:flex-row sm:flex-wrap">
              <Button
                type="button"
                className="h-11 w-full gap-2 sm:h-10 sm:w-auto"
                onClick={() =>
                  router.post(`/periodizations/${periodization.id}/inline_edit`)
                }
              >
                <PencilIcon className="size-4" />
                Editar
              </Button>
              <PrintButton enabled href={printablePath} />
            </div>
          )}

          <section className="flex flex-col gap-2">
            <h2 className="text-lg font-medium">Plano</h2>
            <Markdown content={version.bodyMd} placeholder="Plano sem conteúdo." />
          </section>

          <WorkoutsTabs workouts={version.workouts} />
        </>
      ) : (
        <div className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">
            Esta periodização ainda não tem uma versão ativa.
          </p>
          <div className="no-print">
            <PrintButton enabled={false} href={printablePath} />
          </div>
        </div>
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

function WorkoutsTabs({ workouts }: { workouts: Workout[] }) {
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
        <WorkoutsTabsList workouts={workouts} />
        {workouts.map((w) => (
          <TabsContent key={w.id} value={w.id} className="flex flex-col gap-3">
            <BlocksRenderer
              blocks={w.blocks}
              emptyPlaceholder="Treino sem conteúdo."
            />
          </TabsContent>
        ))}
      </Tabs>
    </section>
  )
}

function PrintButton({ enabled, href }: { enabled: boolean; href: string }) {
  const button = (
    <Button
      type="button"
      variant="outline"
      className="h-11 w-full gap-2 sm:h-10 sm:w-auto"
      disabled={!enabled}
      onClick={() => enabled && window.open(href, "_blank", "noopener")}
    >
      <PrinterIcon className="size-4" />
      Imprimir
    </Button>
  )
  if (enabled) return button
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span tabIndex={0}>{button}</span>
      </TooltipTrigger>
      <TooltipContent>
        Aguarde a versão atual ficar pronta para imprimir.
      </TooltipContent>
    </Tooltip>
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
              {v.draft && (
                <Badge variant="secondary" className="ml-auto">
                  Rascunho
                </Badge>
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
