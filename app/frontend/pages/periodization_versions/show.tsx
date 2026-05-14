import { Link, router } from "@inertiajs/react"
import { Loader2Icon, PrinterIcon } from "lucide-react"
import { useState } from "react"

import { PageHeader } from "@/components/page-header"
import {
  PeriodizationVersionView,
  type PeriodizationVersionData,
} from "@/components/periodization-version-view"
import { TranscriptDetails } from "@/components/transcript-details"
import { Button } from "@/components/ui/button"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { useJobStatus } from "@/hooks/use-job-status"

type Version = PeriodizationVersionData & { transcript: string | null }

type Student = { id: string; name: string }

type Props = { version: Version; student: Student; voiceInFlight: boolean }

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
  voiceInFlight,
}: Props) {
  useJobStatus(
    version.status,
    [ "version", "student", "voiceInFlight", "flash", "errors" ],
    { forceActive: voiceInFlight },
  )

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

      {voiceInFlight && <VoiceInFlightBanner />}

      <TranscriptDetails transcript={version.transcript} />

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
          voiceInFlight={voiceInFlight}
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
  voiceInFlight,
}: {
  version: Version
  student: Student
  versionPath: string
  promotePath: string
  voiceInFlight: boolean
}) {
  const printablePath = `/students/${student.id}/periodization/printable`
  const [dirtyWorkoutName, setDirtyWorkoutName] = useState<string | null>(null)

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
        editingDisabled={voiceInFlight}
        onDirtyWorkoutChange={setDirtyWorkoutName}
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
            disabled={voiceInFlight}
            onClick={promoteWithDirtyGuard}
          >
            Salvar como ativa
          </Button>
        </div>
      )}
    </div>
  )
}

function VoiceInFlightBanner() {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-primary/30 bg-primary/5 p-4 text-sm">
      <Loader2Icon
        className="size-5 shrink-0 animate-spin text-primary"
        aria-hidden
      />
      <span>Aplicando edição por voz...</span>
    </div>
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
