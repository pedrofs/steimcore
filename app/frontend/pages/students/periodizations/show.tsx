import { Link, router } from "@inertiajs/react"
import { ChevronDown, FileTextIcon, PencilIcon, PrinterIcon } from "lucide-react"
import { motion } from "motion/react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
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
            <motion.div
              className="no-print flex flex-col gap-2 sm:flex-row sm:flex-wrap"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.075, ease: [0.16, 1, 0.3, 1] }}
            >
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
              <PlanSheet bodyMd={version.bodyMd} studentName={student.name} />
            </motion.div>
          )}

          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
          >
            <WorkoutsTabs workouts={version.workouts} />
          </motion.div>
        </>
      ) : (
        <motion.div
          className="flex flex-col gap-3"
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.1, ease: "easeOut" }}
        >
          <p className="text-sm text-muted-foreground">
            Esta periodização ainda não tem uma versão ativa.
          </p>
          <div className="no-print">
            <PrintButton enabled={false} href={printablePath} />
          </div>
        </motion.div>
      )}

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4, delay: 0.225, ease: "easeOut" }}
      >
        <VersionHistory versions={periodization.versions} />
      </motion.div>

      <div className="flex justify-start">
        <Button asChild variant="outline" className="h-11 sm:h-10">
          <Link href={`/students/${student.id}`}>Voltar ao aluno</Link>
        </Button>
      </div>
    </>
  )
}

function PlanSheet({
  bodyMd,
  studentName,
}: {
  bodyMd: string
  studentName: string
}) {
  return (
    <Sheet>
      <SheetTrigger asChild>
        <Button
          type="button"
          variant="outline"
          className="h-11 w-full gap-2 sm:h-10 sm:w-auto"
        >
          <FileTextIcon className="size-4" />
          Plano
        </Button>
      </SheetTrigger>
      <SheetContent
        side="right"
        className="flex w-full flex-col gap-0 p-0 sm:max-w-lg"
      >
        <SheetHeader className="border-b">
          <SheetTitle className="font-display text-2xl font-extrabold uppercase tracking-tight">
            Plano
          </SheetTitle>
          <SheetDescription>Periodização de {studentName}</SheetDescription>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto p-4">
          <Markdown content={bodyMd} placeholder="Plano sem conteúdo." />
        </div>
      </SheetContent>
    </Sheet>
  )
}

function WorkoutsTabs({ workouts }: { workouts: Workout[] }) {
  if (workouts.length === 0) {
    return (
      <div className="rounded-xl border border-dashed bg-muted/20 p-6 text-center text-sm text-muted-foreground">
        Nenhum treino registrado.
      </div>
    )
  }

  return (
    <Tabs defaultValue={workouts[0].id} className="flex flex-col gap-3">
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
    <Collapsible className="group/history flex flex-col gap-3">
      <CollapsibleTrigger className="flex w-full items-center justify-between gap-2 text-left">
        <h2 className="text-lg font-medium">
          Histórico de versões{" "}
          <span className="text-muted-foreground">({versions.length})</span>
        </h2>
        <ChevronDown
          aria-hidden
          className="size-4 shrink-0 text-muted-foreground transition-transform duration-200 group-data-[state=open]/history:rotate-180"
        />
      </CollapsibleTrigger>
      <CollapsibleContent className="overflow-hidden data-[state=closed]:animate-collapsible-up data-[state=open]:animate-collapsible-down">
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
      </CollapsibleContent>
    </Collapsible>
  )
}
