import { Form, Link, router } from "@inertiajs/react"
import { Loader2Icon } from "lucide-react"

import { PageHeader } from "@/components/page-header"
import { TranscriptDetails } from "@/components/transcript-details"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { useJobStatus } from "@/hooks/use-job-status"

type Recording = {
  id: string
  kind: string
  status:
    | "pending"
    | "transcribing"
    | "transcribed"
    | "generating"
    | "completed"
    | "failed"
  transcript: string
  proposedAnamnesisMd: string | null
  errorMessage: string | null
}

type Student = { id: string; name: string; anamnesisMd: string }

type Props = { student: Student; recording: Recording }

export default function ShowVoiceRecording({ student, recording }: Props) {
  useJobStatus(recording.status, [
    "recording",
    "student",
    "flash",
    "errors",
  ])

  const retryPath = `/students/${student.id}/voice_recordings/${recording.id}/retry`
  const anamnesisCommitPath = `/students/${student.id}/voice_recordings/${recording.id}/anamnesis_commit`

  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Aluno: <span className="font-medium">{student.name}</span>
        </p>
      </PageHeader>

      <StatusBanner recording={recording} />

      {recording.status === "completed" && recording.kind === "anamnesis" && (
        <>
          <TranscriptDetails transcript={recording.transcript} />
          <AnamnesisReview
            action={anamnesisCommitPath}
            proposedAnamnesisMd={recording.proposedAnamnesisMd ?? ""}
            cancelHref={`/students/${student.id}`}
          />
        </>
      )}

      {recording.status === "failed" && (
        <FailureBlock
          errorMessage={recording.errorMessage}
          onRetry={() => router.post(retryPath)}
          studentHref={`/students/${student.id}`}
        />
      )}
    </>
  )
}

function StatusBanner({ recording }: { recording: Recording }) {
  if (recording.status === "failed") return null

  const inFlight = ["pending", "transcribing", "transcribed", "generating"].includes(
    recording.status,
  )
  const message = inFlight
    ? workingMessage(recording.kind)
    : readyMessage(recording.kind)

  return (
    <div className="flex items-center gap-3 rounded-xl border bg-muted/30 p-4 text-sm">
      {inFlight && (
        <Loader2Icon
          className="size-5 shrink-0 animate-spin text-muted-foreground"
          aria-hidden
        />
      )}
      <span>{message}</span>
    </div>
  )
}

function workingMessage(kind: string): string {
  switch (kind) {
    case "periodization_create":
      return "Gerando periodização com IA..."
    case "periodization_edit_workout":
      return "Gerando edição do treino com IA..."
    case "periodization_edit_periodization":
      return "Gerando edição da periodização com IA..."
    default:
      return "Gerando anamnese atualizada com IA..."
  }
}

function readyMessage(kind: string): string {
  switch (kind) {
    case "periodization_create":
      return "Periodização gerada. Abra a versão para revisar."
    case "periodization_edit_workout":
    case "periodization_edit_periodization":
      return "Edição gerada. Abra a nova versão para revisar."
    default:
      return "Anamnese gerada. Revise e salve para atualizar o aluno."
  }
}

function AnamnesisReview({
  action,
  proposedAnamnesisMd,
  cancelHref,
}: {
  action: string
  proposedAnamnesisMd: string
  cancelHref: string
}) {
  return (
    <Form method="post" action={action} className="flex flex-col gap-3">
      {({ processing, errors }) => (
        <>
          <div className="flex flex-col gap-2">
            <label htmlFor="anamnesis_md" className="text-sm font-medium">
              Anamnese proposta (markdown)
            </label>
            <Textarea
              id="anamnesis_md"
              name="anamnesis_md"
              defaultValue={proposedAnamnesisMd}
              rows={16}
              className="min-h-72 font-mono text-sm"
            />
            {errors.anamnesis_md && (
              <p className="text-sm text-destructive">
                {errors.anamnesis_md.join(", ")}
              </p>
            )}
          </div>
          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button asChild variant="outline" className="h-11 sm:h-10">
              <Link href={cancelHref}>Descartar</Link>
            </Button>
            <Button type="submit" disabled={processing} className="h-11 sm:h-10">
              {processing ? "Salvando..." : "Salvar anamnese"}
            </Button>
          </div>
        </>
      )}
    </Form>
  )
}

function FailureBlock({
  errorMessage,
  onRetry,
  studentHref,
}: {
  errorMessage: string | null
  onRetry: () => void
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
        <Button type="button" onClick={onRetry} className="h-11 sm:h-10">
          Tentar novamente
        </Button>
      </div>
    </div>
  )
}
