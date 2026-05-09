import { Form, Head, Link, router, usePage } from "@inertiajs/react"
import { Fragment } from "react"
import { Loader2Icon } from "lucide-react"

import { AppSidebar } from "@/components/app-sidebar"
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar"
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
  const { props } = usePage()
  const title = props.title
  const breadcrumbs = props.breadcrumbs

  useJobStatus(recording.status, [
    "recording",
    "student",
    "flash",
    "errors",
  ])

  const transcriptConfirmationPath = `/students/${student.id}/voice_recordings/${recording.id}/transcript_confirmation`
  const transcriptionPath = `/students/${student.id}/voice_recordings/${recording.id}/transcription`
  const anamnesisCommitPath = `/students/${student.id}/voice_recordings/${recording.id}/anamnesis_commit`

  return (
    <>
      <Head title={title ?? undefined} />
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <header className="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12">
            <div className="flex items-center gap-2 px-4">
              <SidebarTrigger className="-ml-1 size-11 md:size-8" />
              <Separator
                orientation="vertical"
                className="mr-2 data-vertical:h-4 data-vertical:self-auto"
              />
              <Breadcrumb>
                <BreadcrumbList>
                  {breadcrumbs.map((crumb, i) => {
                    const isLast = i === breadcrumbs.length - 1
                    return (
                      <Fragment key={`${crumb.path}-${i}`}>
                        <BreadcrumbItem>
                          {isLast ? (
                            <BreadcrumbPage>{crumb.label}</BreadcrumbPage>
                          ) : (
                            <BreadcrumbLink asChild>
                              <Link href={crumb.path}>{crumb.label}</Link>
                            </BreadcrumbLink>
                          )}
                        </BreadcrumbItem>
                        {!isLast && <BreadcrumbSeparator />}
                      </Fragment>
                    )
                  })}
                </BreadcrumbList>
              </Breadcrumb>
            </div>
          </header>
          <div className="flex flex-1 flex-col gap-6 p-4 pt-0">
            <div className="flex flex-col gap-1">
              {title && (
                <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                  {title}
                </h1>
              )}
              <p className="text-sm text-muted-foreground">
                Aluno: <span className="font-medium">{student.name}</span>
              </p>
            </div>

            <StatusBanner recording={recording} />

            {recording.status === "transcribed" && (
              <TranscriptReview
                action={transcriptConfirmationPath}
                transcript={recording.transcript}
                cancelHref={`/students/${student.id}`}
              />
            )}

            {recording.status === "completed" && recording.kind === "anamnesis" && (
              <AnamnesisReview
                action={anamnesisCommitPath}
                proposedAnamnesisMd={recording.proposedAnamnesisMd ?? ""}
                cancelHref={`/students/${student.id}`}
              />
            )}

            {recording.status === "failed" && (
              <FailureBlock
                errorMessage={recording.errorMessage}
                onRetry={() => router.post(transcriptionPath)}
                studentHref={`/students/${student.id}`}
              />
            )}
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}

function StatusBanner({ recording }: { recording: Recording }) {
  const messages: Record<Recording["status"], string> =
    recording.kind === "periodization_create"
      ? {
          pending: "Áudio recebido. Iniciando transcrição...",
          transcribing: "Transcrevendo áudio...",
          transcribed: "Transcrição pronta. Revise antes de gerar a periodização.",
          generating: "Gerando periodização com IA...",
          completed: "Periodização gerada. Abra a versão para revisar.",
          failed: "Algo deu errado.",
        }
      : recording.kind === "periodization_edit_workout"
        ? {
            pending: "Áudio recebido. Iniciando transcrição...",
            transcribing: "Transcrevendo áudio...",
            transcribed: "Transcrição pronta. Revise antes de gerar a edição do treino.",
            generating: "Gerando edição do treino com IA...",
            completed: "Edição gerada. Abra a nova versão para revisar.",
            failed: "Algo deu errado.",
          }
        : {
            pending: "Áudio recebido. Iniciando transcrição...",
            transcribing: "Transcrevendo áudio...",
            transcribed: "Transcrição pronta. Revise antes de gerar a anamnese.",
            generating: "Gerando anamnese atualizada com IA...",
            completed: "Anamnese gerada. Revise e salve para atualizar o aluno.",
            failed: "Algo deu errado.",
          }
  const showSpinner = ["pending", "transcribing", "generating"].includes(
    recording.status,
  )

  if (recording.status === "failed") return null

  return (
    <div className="flex items-center gap-3 rounded-xl border bg-muted/30 p-4 text-sm">
      {showSpinner && (
        <Loader2Icon
          className="size-5 shrink-0 animate-spin text-muted-foreground"
          aria-hidden
        />
      )}
      <span>{messages[recording.status]}</span>
    </div>
  )
}

function TranscriptReview({
  action,
  transcript,
  cancelHref,
}: {
  action: string
  transcript: string
  cancelHref: string
}) {
  return (
    <Form method="post" action={action} className="flex flex-col gap-3">
      {({ processing, errors }) => (
        <>
          <div className="flex flex-col gap-2">
            <label htmlFor="transcript" className="text-sm font-medium">
              Transcrição
            </label>
            <Textarea
              id="transcript"
              name="transcript"
              defaultValue={transcript}
              rows={10}
              className="min-h-48 font-mono text-sm"
            />
            {errors.transcript && (
              <p className="text-sm text-destructive">
                {errors.transcript.join(", ")}
              </p>
            )}
          </div>
          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button asChild variant="outline" className="h-11 sm:h-10">
              <Link href={cancelHref}>Cancelar</Link>
            </Button>
            <Button type="submit" disabled={processing} className="h-11 sm:h-10">
              {processing ? "Confirmando..." : "Confirmar transcrição"}
            </Button>
          </div>
        </>
      )}
    </Form>
  )
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
          Tentar transcrever novamente
        </Button>
      </div>
    </div>
  )
}
