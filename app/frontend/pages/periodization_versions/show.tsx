import { Link, router } from "@inertiajs/react"
import { Loader2Icon, PrinterIcon } from "lucide-react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { useJobStatus } from "@/hooks/use-job-status"

type Workout = {
  id: string
  name: string
  position: number
  blocks: Block[]
}

type Version = {
  id: string
  status: "pending" | "generating" | "completed" | "failed"
  bodyMd: string
  errorMessage: string | null
  promoted: boolean
  readOnly: boolean
  periodizationId: string
  workouts: Workout[]
}

type Student = { id: string; name: string }

type Props = { version: Version; student: Student }

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
        Salve esta versão como ativa antes de imprimir.
      </TooltipContent>
    </Tooltip>
  )
}

export default function ShowPeriodizationVersion({ version, student }: Props) {
  useJobStatus(version.status, [ "version", "student", "flash", "errors" ])

  const versionPath = `/periodization_versions/${version.id}`
  const promotePath = `${versionPath}/promotion`

  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Aluno: <span className="font-medium">{student.name}</span>
        </p>
      </PageHeader>

      <StatusBanner status={version.status} />

      {version.status === "failed" && (
        <FailureBlock
          errorMessage={version.errorMessage}
          onDiscard={() => router.delete(versionPath)}
          studentHref={`/students/${student.id}`}
        />
      )}

      {version.status === "completed" && (
        <CompletedVersion
          version={version}
          student={student}
          versionPath={versionPath}
          promotePath={promotePath}
        />
      )}
    </>
  )
}

function CompletedVersion({
  version,
  student,
  versionPath,
  promotePath,
}: {
  version: Version
  student: Student
  versionPath: string
  promotePath: string
}) {
  const printablePath = `/students/${student.id}/periodization/printable`

  return (
    <div className="flex flex-col gap-6">
      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Plano</h2>
        <Markdown content={version.bodyMd} placeholder="Plano sem conteúdo." />
      </section>

      <WorkoutsTabs workouts={version.workouts} />

      {version.readOnly ? (
        <div className="no-print flex flex-col-reverse gap-2 sm:flex-row sm:justify-between">
          <Button asChild variant="outline" className="h-11 sm:h-10">
            <Link
              href={`/students/${student.id}/periodizations/${version.periodizationId}`}
            >
              Voltar à periodização
            </Link>
          </Button>
          <PrintButton enabled={version.promoted} href={printablePath} />
        </div>
      ) : (
        <div className="no-print flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <PrintButton enabled={version.promoted} href={printablePath} />
          <Button
            type="button"
            variant="outline"
            className="h-11 sm:h-10"
            onClick={() => {
              if (confirm("Descartar esta versão?")) {
                router.delete(versionPath)
              }
            }}
          >
            Descartar
          </Button>
          <Button
            type="button"
            className="h-11 sm:h-10"
            onClick={() => router.post(promotePath)}
          >
            Salvar como ativa
          </Button>
        </div>
      )}
    </div>
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
        <TabsList className="flex w-full flex-wrap justify-start gap-1">
          {workouts.map((w) => (
            <TabsTrigger key={w.id} value={w.id}>
              {w.name}
            </TabsTrigger>
          ))}
        </TabsList>
        {workouts.map((w) => (
          <TabsContent key={w.id} value={w.id}>
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

function StatusBanner({ status }: { status: Version["status"] }) {
  const messages: Record<Version["status"], string> = {
    pending: "Aguardando início da geração...",
    generating: "Gerando periodização com IA...",
    completed: "Periodização gerada. Revise antes de salvar.",
    failed: "Algo deu errado.",
  }
  const showSpinner = status === "pending" || status === "generating"
  if (status === "failed") return null

  return (
    <div className="flex items-center gap-3 rounded-xl border bg-muted/30 p-4 text-sm">
      {showSpinner && (
        <Loader2Icon
          className="size-5 shrink-0 animate-spin text-muted-foreground"
          aria-hidden
        />
      )}
      <span>{messages[status]}</span>
    </div>
  )
}

function FailureBlock({
  errorMessage,
  onDiscard,
  studentHref,
}: {
  errorMessage: string | null
  onDiscard: () => void
  studentHref: string
}) {
  return (
    <div className="flex flex-col gap-3 rounded-xl border border-destructive/30 bg-destructive/5 p-4">
      <p className="text-sm">
        <span className="font-medium">Falha:</span>{" "}
        {errorMessage ?? "Erro desconhecido."}
      </p>
      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button asChild variant="outline" className="h-11 sm:h-10">
          <Link href={studentHref}>Voltar ao aluno</Link>
        </Button>
        <Button type="button" onClick={onDiscard} className="h-11 sm:h-10">
          Descartar versão
        </Button>
      </div>
    </div>
  )
}
