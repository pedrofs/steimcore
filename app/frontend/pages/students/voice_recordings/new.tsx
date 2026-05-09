import { Head, Link, router, usePage } from "@inertiajs/react"
import { Fragment, useState } from "react"
import { CircleStopIcon, MicIcon, Trash2Icon } from "lucide-react"

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
import {
  useVoiceRecorder,
  VOICE_RECORDER_MAX_MS,
} from "@/hooks/use-voice-recorder"

type Student = { id: string; name: string }
type Kind = "anamnesis" | "periodization_create"
type Props = { student: Student; kind: Kind }

export default function NewVoiceRecording({ student, kind }: Props) {
  const { props } = usePage()
  const title = props.title
  const breadcrumbs = props.breadcrumbs

  const recorder = useVoiceRecorder()
  const [submitting, setSubmitting] = useState(false)

  const handleSubmit = () => {
    if (!recorder.audio) return
    const extension = guessExtension(recorder.audio.mimeType)
    const baseName = kind === "periodization_create" ? "periodization" : "anamnesis"
    const file = new File([recorder.audio.blob], `${baseName}.${extension}`, {
      type: recorder.audio.mimeType,
    })
    setSubmitting(true)
    router.post(
      `/students/${student.id}/voice_recordings`,
      { audio: file, kind },
      {
        forceFormData: true,
        onFinish: () => setSubmitting(false),
      },
    )
  }


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
                Aluno: <span className="font-medium">{student.name}</span>.{" "}
                {kind === "periodization_create"
                  ? "Descreva a periodização. A gravação para automaticamente em 3 minutos."
                  : "A gravação para automaticamente em 3 minutos."}
              </p>
            </div>

            <section className="flex flex-col items-center gap-6 rounded-2xl border bg-muted/20 p-6">
              <Timer
                elapsedMs={recorder.elapsedMs}
                state={recorder.state}
              />

              {recorder.state === "recording" ? (
                <Button
                  type="button"
                  size="lg"
                  variant="destructive"
                  className="h-16 w-full max-w-xs gap-2 text-base"
                  onClick={recorder.stop}
                >
                  <CircleStopIcon className="size-5" />
                  Parar gravação
                </Button>
              ) : recorder.state === "stopped" && recorder.audio ? (
                <div className="flex w-full flex-col gap-3">
                  <audio
                    controls
                    src={URL.createObjectURL(recorder.audio.blob)}
                    className="w-full"
                  />
                  <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
                    <Button
                      type="button"
                      variant="outline"
                      className="h-11 sm:h-10"
                      onClick={recorder.reset}
                      disabled={submitting}
                    >
                      <Trash2Icon className="mr-1 size-4" />
                      Descartar
                    </Button>
                    <Button
                      type="button"
                      className="h-11 sm:h-10"
                      onClick={handleSubmit}
                      disabled={submitting}
                    >
                      {submitting ? "Enviando..." : "Enviar para transcrição"}
                    </Button>
                  </div>
                </div>
              ) : (
                <Button
                  type="button"
                  size="lg"
                  className="h-16 w-full max-w-xs gap-2 text-base"
                  onClick={recorder.start}
                >
                  <MicIcon className="size-5" />
                  Iniciar gravação
                </Button>
              )}

              {recorder.errorMessage && (
                <p className="text-sm text-destructive" role="alert">
                  {recorder.errorMessage}
                </p>
              )}
            </section>

            <div className="flex justify-start">
              <Button asChild variant="outline" className="h-11 sm:h-10">
                <Link href={`/students/${student.id}`}>Voltar ao aluno</Link>
              </Button>
            </div>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}

function Timer({
  elapsedMs,
  state,
}: {
  elapsedMs: number
  state: string
}) {
  const remaining = Math.max(0, VOICE_RECORDER_MAX_MS - elapsedMs)
  const display = state === "recording" ? remaining : elapsedMs
  return (
    <div className="flex flex-col items-center gap-1">
      <span
        className={
          "font-mono text-5xl tabular-nums " +
          (state === "recording" ? "text-destructive" : "text-foreground")
        }
        aria-live="polite"
      >
        {formatTime(display)}
      </span>
      <span className="text-xs uppercase tracking-wide text-muted-foreground">
        {state === "recording"
          ? "Tempo restante"
          : state === "stopped"
            ? "Duração"
            : "Pronto para gravar"}
      </span>
    </div>
  )
}

function formatTime(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
}

function guessExtension(mimeType: string): string {
  if (mimeType.includes("webm")) return "webm"
  if (mimeType.includes("ogg")) return "ogg"
  if (mimeType.includes("mp4") || mimeType.includes("mpeg")) return "m4a"
  return "webm"
}
