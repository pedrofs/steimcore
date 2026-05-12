import { Link, router } from "@inertiajs/react"
import { Loader2Icon, MicIcon, PencilIcon, PrinterIcon } from "lucide-react"
import { useState } from "react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { PageHeader } from "@/components/page-header"
import { TranscriptDetails } from "@/components/transcript-details"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent } from "@/components/ui/tabs"
import { WorkoutEditor } from "@/components/workout-editor"
import { WorkoutsTabsList } from "@/components/workouts-tabs-list"
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
  transcript: string | null
  workouts: Workout[]
}

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
  const [editingWorkoutId, setEditingWorkoutId] = useState<string | null>(null)
  const editingDisabled = voiceInFlight

  return (
    <div className="flex flex-col gap-6">
      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Plano</h2>
        <Markdown content={version.bodyMd} placeholder="Plano sem conteúdo." />
      </section>

      <WorkoutsTabs
        version={version}
        editingWorkoutId={editingWorkoutId}
        onEdit={(id) => setEditingWorkoutId(id)}
        onCancelEdit={() => setEditingWorkoutId(null)}
        editingDisabled={editingDisabled}
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
          {!voiceInFlight && (
            <Button
              type="button"
              variant="outline"
              className="h-11 gap-2 sm:h-10"
              onClick={() => router.post(`${versionPath}/edit`)}
            >
              <MicIcon className="size-4" />
              Modificar periodização
            </Button>
          )}
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
            onClick={() => router.post(promotePath)}
          >
            Salvar como ativa
          </Button>
        </div>
      )}
    </div>
  )
}

function WorkoutsTabs({
  version,
  editingWorkoutId,
  onEdit,
  onCancelEdit,
  editingDisabled,
}: {
  version: Version
  editingWorkoutId: string | null
  onEdit: (id: string) => void
  onCancelEdit: () => void
  editingDisabled: boolean
}) {
  const workouts = version.workouts
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

  const someoneEditing = editingWorkoutId != null
  const showEditControls = !version.readOnly && !someoneEditing && !editingDisabled

  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Treinos</h2>
      <Tabs defaultValue={workouts[0].id}>
        <WorkoutsTabsList workouts={workouts} />
        {workouts.map((w) => (
          <TabsContent key={w.id} value={w.id} className="flex flex-col gap-3">
            {editingWorkoutId === w.id ? (
              <WorkoutEditor
                versionId={version.id}
                workoutId={w.id}
                blocks={w.blocks}
                onCancel={onCancelEdit}
                onSaved={onCancelEdit}
              />
            ) : (
              <>
                <BlocksRenderer
                  blocks={w.blocks}
                  emptyPlaceholder="Treino sem conteúdo."
                />
                {showEditControls && (
                  <div className="mt-1 flex flex-col gap-2 sm:flex-row sm:justify-end">
                    <Button
                      type="button"
                      variant="outline"
                      className="h-11 w-full gap-2 sm:h-10 sm:w-auto"
                      onClick={() =>
                        router.post(
                          `/periodization_versions/${version.id}/workouts/${w.id}/edit`,
                        )
                      }
                    >
                      <MicIcon className="size-4" />
                      Editar este treino
                    </Button>
                    <Button
                      type="button"
                      variant="outline"
                      className="h-11 w-full gap-2 sm:h-10 sm:w-auto"
                      onClick={() => onEdit(w.id)}
                    >
                      <PencilIcon className="size-4" />
                      Editar inline
                    </Button>
                  </div>
                )}
              </>
            )}
          </TabsContent>
        ))}
      </Tabs>
    </section>
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
