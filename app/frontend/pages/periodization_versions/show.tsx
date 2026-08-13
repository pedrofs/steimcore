import { Link, router } from "@inertiajs/react"
import { Loader2Icon, PrinterIcon } from "lucide-react"
import { useState } from "react"

import { PageHeader } from "@/components/page-header"
import {
  PeriodizationVersionView,
  type PeriodizationVersionData,
} from "@/components/periodization-version-view"
import { SaveAsTemplateDialog } from "@/components/save-as-template-dialog"
import { Button } from "@/components/ui/button"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { useJobStatus } from "@/hooks/use-job-status"
import type { ExerciseSuggestion } from "@/lib/exercise-suggestions"

type Version = PeriodizationVersionData

type Student = { id: string; name: string }

type Props = {
  version: Version
  student: Student
  exerciseSuggestions: ExerciseSuggestion[]
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
        Salve esta versão como ativa antes de imprimir.
      </TooltipContent>
    </Tooltip>
  )
}

export default function ShowPeriodizationVersion({
  version,
  student,
  exerciseSuggestions,
}: Props) {
  useJobStatus(version.status, [ "version", "student", "flash", "errors" ])

  const versionPath = `/periodization_versions/${version.id}`
  const promotePath = `${versionPath}/promotion`

  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Aluno:{" "}
          <Link
            href={`/students/${student.id}`}
            className="font-medium hover:underline"
          >
            {student.name}
          </Link>
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
          exerciseSuggestions={exerciseSuggestions}
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
  exerciseSuggestions,
}: {
  version: Version
  student: Student
  versionPath: string
  promotePath: string
  exerciseSuggestions: ExerciseSuggestion[]
}) {
  const printablePath = `/students/${student.id}/periodization/printable`
  const [dirtyWorkoutName, setDirtyWorkoutName] = useState<string | null>(null)
  const [saveTemplateOpen, setSaveTemplateOpen] = useState(false)

  const promoteWithDirtyGuard = () => {
    if (dirtyWorkoutName) {
      if (
        !window.confirm(
          `Promover descartará as alterações não salvas em ${dirtyWorkoutName}. Continuar?`,
        )
      ) {
        return
      }
    }
    router.post(promotePath)
  }

  return (
    <div className="flex flex-col gap-6">
      <PeriodizationVersionView
        version={version}
        onDirtyWorkoutChange={setDirtyWorkoutName}
        exerciseSuggestions={exerciseSuggestions}
      />

      {version.readOnly ? (
        <div className="no-print flex flex-col-reverse gap-2 sm:flex-row sm:justify-between">
          <Button asChild variant="outline" className="h-11 sm:h-10">
            <Link
              href={`/students/${student.id}/periodizations/${version.periodizationId}`}
            >
              Voltar à periodização
            </Link>
          </Button>
          <div className="flex flex-col-reverse gap-2 sm:flex-row">
            <SaveAsTemplateButton onClick={() => setSaveTemplateOpen(true)} />
            <PrintButton enabled={version.promoted} href={printablePath} />
          </div>
        </div>
      ) : (
        <div className="no-print flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <SaveAsTemplateButton onClick={() => setSaveTemplateOpen(true)} />
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
            onClick={promoteWithDirtyGuard}
          >
            Salvar como ativa
          </Button>
        </div>
      )}

      <SaveAsTemplateDialog
        versionId={version.id}
        open={saveTemplateOpen}
        onOpenChange={setSaveTemplateOpen}
      />
    </div>
  )
}

function SaveAsTemplateButton({ onClick }: { onClick: () => void }) {
  return (
    <Button
      type="button"
      variant="outline"
      className="h-11 w-full gap-2 sm:h-10 sm:w-auto"
      onClick={onClick}
    >
      Salvar como modelo
    </Button>
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
