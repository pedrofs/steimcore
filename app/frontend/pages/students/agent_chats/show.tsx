import { Link, router } from "@inertiajs/react"
import {
  AlertCircle,
  ArrowLeft,
  CalendarRange,
  Camera,
  Dumbbell,
  FileText,
  Loader2,
  Mic,
  Paperclip,
  Play,
  Send,
  Sparkles,
  Square,
  X,
} from "lucide-react"
import { useCallback, useEffect, useMemo, useRef, useState } from "react"

import { ArtifactDrawer } from "@/components/artifact-drawer"
import { Markdown } from "@/components/markdown"
import type {
  PeriodizationVersionData,
  PeriodizationViewScope,
} from "@/components/periodization-version-view"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { useChatStream, type LiveMessage, type ToolCallEvent } from "@/hooks/use-chat-stream"
import { cn } from "@/lib/utils"

type Student = {
  id: string
  name: string
  age: number | null
  sex: string | null
  primaryGoal: string | null
  weeklyFrequency: number | null
  anamnesisMd: string
}

type ChatState = "idle" | "running"

type Chat = {
  id: string
  state: ChatState
}

type UpdateAnamnesisResult = { ok?: boolean; summaryMd?: string; error?: string }

type PeriodizationToolResult = {
  ok?: boolean
  versionId?: string
  versionNumber?: number
  scope?: string
  workoutCount?: number
  summaryMd?: string
  error?: string
}

type UpdateWorkoutResult = {
  ok?: boolean
  versionId?: string
  workoutId?: string
  workoutName?: string
  versionNumber?: number
  summaryMd?: string
  error?: string
}

type ToolCall = {
  id: string
  name: string
  arguments: Record<string, unknown> | null
  result:
    | UpdateAnamnesisResult
    | PeriodizationToolResult
    | UpdateWorkoutResult
    | Record<string, unknown>
    | null
}

type AttachmentKind = "audio" | "image" | "pdf" | "file"

type Attachment = {
  id: string
  filename: string
  contentType: string
  byteSize: number
  url: string
  kind: AttachmentKind
}

type Message = {
  id: string
  role: "user" | "assistant" | "tool" | "system"
  content: string | null
  createdAt: string
  trainerEmailPrefix: string | null
  toolCalls: ToolCall[]
  attachments: Attachment[]
}

type SuggestionWorkout = {
  id: string
  name: string
  position: number
}

type Props = {
  student: Student
  chat: Chat
  messages: Message[]
  openVersion: PeriodizationVersionData | null
  hasActivePeriodization: boolean
  suggestionWorkouts: SuggestionWorkout[]
}

type DrawerState = {
  open: boolean
  versionId: string | null
  workoutId: string | null
}

const MAX_ATTACHMENT_COUNT = 5
const MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024

export default function AgentChatShow({
  student,
  chat,
  messages,
  openVersion,
  hasActivePeriodization,
  suggestionWorkouts,
}: Props) {
  const visibleMessages = useMemo(
    () => messages.filter((m) => m.role !== "tool" && m.role !== "system"),
    [messages],
  )

  const { liveMessage, error, clearError } = useChatStream(chat.id, {
    reloadProps: [ "messages", "open_version", "chat" ],
  })

  const [composerContent, setComposerContent] = useState("")
  const textareaRef = useRef<HTMLTextAreaElement | null>(null)

  const handlePrefill = useCallback((text: string) => {
    setComposerContent(text)
    requestAnimationFrame(() => {
      const el = textareaRef.current
      if (!el) return
      el.focus()
      el.setSelectionRange(text.length, text.length)
    })
  }, [])

  const isEmptyChat = visibleMessages.length === 0 && liveMessage == null
  const showSuggestionChips = isEmptyChat && chat.state !== "running"

  const scrollRef = useRef<HTMLDivElement | null>(null)
  useEffect(() => {
    const el = scrollRef.current
    if (!el) return
    el.scrollTop = el.scrollHeight
  }, [visibleMessages.length, liveMessage?.content, liveMessage?.toolCalls.length])

  const [drawerState, setDrawerState] = useState<DrawerState>({
    open: false,
    versionId: null,
    workoutId: null,
  })

  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null)

  const chatPath = `/students/${student.id}/agent_chat`

  const refreshOpenVersion = useCallback(
    (versionId: string | null, opts: { replace?: boolean } = {}) => {
      router.reload({
        only: [ "open_version" ],
        data: versionId
          ? { open_version_id: versionId }
          : { open_version_id: undefined },
        replace: opts.replace ?? false,
      })
    },
    [],
  )

  const openDrawer = useCallback(
    (versionId: string, workoutId: string | null) => {
      setDrawerState({ open: true, versionId, workoutId })
      refreshOpenVersion(versionId, { replace: false })
    },
    [ refreshOpenVersion ],
  )

  const handleOpenChange = useCallback(
    (open: boolean) => {
      if (open) return
      setDrawerState((prev) => ({ ...prev, open: false }))
      refreshOpenVersion(null, { replace: true })
    },
    [ refreshOpenVersion ],
  )

  const prevOpenVersionIdRef = useRef<string | null>(openVersion?.id ?? null)
  useEffect(() => {
    const prevId = prevOpenVersionIdRef.current
    prevOpenVersionIdRef.current = openVersion?.id ?? null
    if (
      prevId != null &&
      openVersion == null &&
      drawerState.open &&
      prevId === drawerState.versionId
    ) {
      setDrawerState({ open: false, versionId: null, workoutId: null })
    }
  }, [openVersion, drawerState.open, drawerState.versionId])

  const handleEscalateToPeriodization = useCallback(() => {
    setDrawerState((prev) =>
      prev.versionId
        ? { open: true, versionId: prev.versionId, workoutId: null }
        : prev,
    )
  }, [])

  const drawerVersion =
    drawerState.versionId && openVersion?.id === drawerState.versionId
      ? openVersion
      : null

  const drawerScope: PeriodizationViewScope = drawerState.workoutId
    ? { kind: "workout", workoutId: drawerState.workoutId }
    : { kind: "periodization" }

  const drawerReturnTo = drawerState.versionId
    ? buildReturnTo(chatPath, drawerState.versionId, drawerState.workoutId)
    : chatPath

  return (
    <div className="flex h-dvh flex-col bg-background">
      <ChatHeader student={student} />

      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto px-4 py-4 sm:px-6"
        aria-live="polite"
      >
        {visibleMessages.length === 0 && liveMessage == null ? (
          <EmptyState studentName={student.name} />
        ) : (
          <ol className="mx-auto flex max-w-3xl flex-col gap-4">
            {visibleMessages.map((message) => (
              <MessageBubble
                key={message.id}
                message={message}
                onOpen={openDrawer}
                onLightbox={setLightboxUrl}
              />
            ))}
            {liveMessage != null && (
              <LiveMessageBubble live={liveMessage} />
            )}
            {chat.state === "running" && liveMessage == null && (
              <ThinkingBubble />
            )}
          </ol>
        )}
        {error != null && <ErrorBubble error={error} onDismiss={clearError} />}
      </div>

      <Composer
        studentId={student.id}
        disabled={chat.state === "running" || liveMessage != null}
        content={composerContent}
        onContentChange={setComposerContent}
        textareaRef={textareaRef}
        suggestionChips={
          showSuggestionChips ? (
            <SuggestionChips
              studentName={student.name}
              hasActivePeriodization={hasActivePeriodization}
              workouts={suggestionWorkouts}
              onPrefill={handlePrefill}
            />
          ) : null
        }
      />

      <ArtifactDrawer
        open={drawerState.open}
        onOpenChange={handleOpenChange}
        version={drawerVersion}
        scope={drawerScope}
        onEscalateToPeriodization={
          drawerState.workoutId ? handleEscalateToPeriodization : undefined
        }
        returnTo={drawerReturnTo}
      />

      {lightboxUrl != null && (
        <Lightbox url={lightboxUrl} onClose={() => setLightboxUrl(null)} />
      )}
    </div>
  )
}

function buildReturnTo(
  chatPath: string,
  versionId: string,
  workoutId: string | null,
): string {
  const params = new URLSearchParams({ open_version_id: versionId })
  if (workoutId) params.set("open_workout_id", workoutId)
  return `${chatPath}?${params.toString()}`
}

function ChatHeader({ student }: { student: Student }) {
  const chips: string[] = []
  if (student.age != null) chips.push(`${student.age} anos`)
  if (student.sex) chips.push(student.sex)
  if (student.primaryGoal) chips.push(student.primaryGoal)
  if (student.weeklyFrequency != null)
    chips.push(`${student.weeklyFrequency}x/sem`)

  return (
    <header className="sticky top-0 z-10 flex flex-col gap-2 border-b border-border/60 bg-background/95 px-4 py-3 backdrop-blur sm:px-6">
      <div className="flex items-center gap-3">
        <Button
          asChild
          variant="ghost"
          size="icon"
          className="-ml-2 size-10 shrink-0"
          aria-label="Voltar ao perfil"
        >
          <Link href={`/students/${student.id}`}>
            <ArrowLeft className="size-5" />
          </Link>
        </Button>
        <Avatar className="size-9">
          <AvatarFallback className="bg-brand/10 text-sm font-semibold text-brand">
            {initials(student.name)}
          </AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1">
          <p className="truncate font-display text-base font-semibold leading-tight">
            {student.name}
          </p>
          <p className="text-xs text-muted-foreground">Chat com o assistente</p>
        </div>
      </div>
      {chips.length > 0 && (
        <div className="flex flex-wrap gap-1.5 pl-12">
          {chips.map((chip) => (
            <Badge key={chip} variant="secondary" className="rounded-full">
              {chip}
            </Badge>
          ))}
        </div>
      )}
    </header>
  )
}

type OpenDrawer = (versionId: string, workoutId: string | null) => void
type OpenLightbox = (url: string) => void

function MessageBubble({
  message,
  onOpen,
  onLightbox,
}: {
  message: Message
  onOpen: OpenDrawer
  onLightbox: OpenLightbox
}) {
  const isTrainer = message.role === "user"
  const hasText = message.content != null && message.content.trim().length > 0
  return (
    <li
      className={cn(
        "flex flex-col gap-1",
        isTrainer ? "items-end" : "items-start",
      )}
    >
      {message.attachments.length > 0 && (
        <MessageAttachments
          attachments={message.attachments}
          isTrainer={isTrainer}
          onLightbox={onLightbox}
        />
      )}
      {hasText && (
        <div
          className={cn(
            "max-w-[85%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed sm:max-w-[75%]",
            isTrainer
              ? "rounded-br-sm bg-brand text-brand-foreground"
              : "rounded-bl-sm bg-muted text-foreground",
          )}
        >
          <Markdown content={message.content!} className="text-sm" />
        </div>
      )}
      {message.toolCalls.length > 0 && (
        <div className="flex w-full max-w-[85%] flex-col gap-1.5 sm:max-w-[75%]">
          {message.toolCalls.map((tc) => (
            <ToolCallCard key={tc.id} toolCall={tc} onOpen={onOpen} />
          ))}
        </div>
      )}
      {isTrainer && message.trainerEmailPrefix && (
        <span className="px-1 text-[10px] uppercase tracking-wide text-muted-foreground">
          {message.trainerEmailPrefix}
        </span>
      )}
    </li>
  )
}

function MessageAttachments({
  attachments,
  isTrainer,
  onLightbox,
}: {
  attachments: Attachment[]
  isTrainer: boolean
  onLightbox: OpenLightbox
}) {
  return (
    <div
      className={cn(
        "flex max-w-[85%] flex-col gap-1.5 sm:max-w-[75%]",
        isTrainer ? "items-end" : "items-start",
      )}
    >
      {attachments.map((att) => {
        if (att.kind === "audio") {
          return (
            <audio
              key={att.id}
              controls
              src={att.url}
              className="w-full max-w-[280px]"
              preload="metadata"
            />
          )
        }
        if (att.kind === "image") {
          return (
            <button
              key={att.id}
              type="button"
              onClick={() => onLightbox(att.url)}
              className="overflow-hidden rounded-xl border border-border focus:outline-none focus-visible:ring-2 focus-visible:ring-brand"
              aria-label={`Abrir ${att.filename}`}
            >
              <img
                src={att.url}
                alt={att.filename}
                className="block max-h-64 max-w-[260px] object-cover"
              />
            </button>
          )
        }
        return (
          <a
            key={att.id}
            href={att.url}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 rounded-xl border border-border bg-muted/40 px-3 py-2 text-xs text-foreground hover:bg-muted/70"
          >
            <FileText className="size-4 shrink-0 text-muted-foreground" aria-hidden />
            <div className="flex min-w-0 flex-col">
              <span className="truncate font-medium">{att.filename}</span>
              <span className="text-muted-foreground">{formatBytes(att.byteSize)}</span>
            </div>
          </a>
        )
      })}
    </div>
  )
}

function ToolCallCard({
  toolCall,
  onOpen,
}: {
  toolCall: ToolCall
  onOpen: OpenDrawer
}) {
  if (toolCall.name === "update_anamnesis") {
    return <UpdateAnamnesisCard toolCall={toolCall} />
  }
  if (
    toolCall.name === "create_periodization" ||
    toolCall.name === "update_periodization"
  ) {
    return <PeriodizationCard toolCall={toolCall} onOpen={onOpen} />
  }
  if (toolCall.name === "update_workout") {
    return <UpdateWorkoutCard toolCall={toolCall} onOpen={onOpen} />
  }
  return (
    <div className="rounded-xl border border-border bg-muted/40 px-3 py-2 text-xs text-muted-foreground">
      {toolCall.name}
    </div>
  )
}

function UpdateAnamnesisCard({ toolCall }: { toolCall: ToolCall }) {
  const result = (toolCall.result ?? {}) as UpdateAnamnesisResult
  const args = (toolCall.arguments ?? {}) as { summaryMd?: string }
  const summary =
    (result.summaryMd && result.summaryMd.trim()) ||
    (args.summaryMd && args.summaryMd.trim()) ||
    "anamnese atualizada"
  if (result.error) {
    return (
      <div className="flex items-start gap-2 rounded-xl border border-destructive/40 bg-destructive/5 px-3 py-2 text-xs text-destructive">
        <FileText className="mt-0.5 size-3.5 shrink-0" aria-hidden />
        <span>Falha ao atualizar anamnese: {result.error}</span>
      </div>
    )
  }
  return (
    <div className="flex items-start gap-2 rounded-xl border border-brand/30 bg-brand/5 px-3 py-2 text-xs text-foreground">
      <FileText className="mt-0.5 size-3.5 shrink-0 text-brand" aria-hidden />
      <span>
        <span className="font-medium">Anamnese atualizada</span> · {summary}
      </span>
    </div>
  )
}

function PeriodizationCard({
  toolCall,
  onOpen,
}: {
  toolCall: ToolCall
  onOpen: OpenDrawer
}) {
  const result = (toolCall.result ?? {}) as PeriodizationToolResult
  const args = (toolCall.arguments ?? {}) as { summaryMd?: string }
  const summary =
    (result.summaryMd && result.summaryMd.trim()) ||
    (args.summaryMd && args.summaryMd.trim()) ||
    null

  const isCreate = toolCall.name === "create_periodization"
  const title = isCreate ? "Nova periodização criada" : "Periodização atualizada"
  const errorTitle = isCreate
    ? "Falha ao criar periodização"
    : "Falha ao atualizar periodização"

  if (result.error) {
    return (
      <div className="flex items-start gap-2 rounded-xl border border-destructive/40 bg-destructive/5 px-3 py-2 text-xs text-destructive">
        <CalendarRange className="mt-0.5 size-3.5 shrink-0" aria-hidden />
        <span>
          {errorTitle}: {result.error}
        </span>
      </div>
    )
  }

  const metaParts: string[] = []
  if (typeof result.workoutCount === "number") {
    metaParts.push(`${result.workoutCount} treino${result.workoutCount === 1 ? "" : "s"}`)
  }
  if (typeof result.versionNumber === "number") {
    metaParts.push(`esboço v${result.versionNumber}`)
  }

  return (
    <div className="flex flex-col gap-2 rounded-xl border border-brand/30 bg-brand/5 px-3 py-2.5 text-xs text-foreground">
      <div className="flex items-start gap-2">
        <CalendarRange
          className="mt-0.5 size-3.5 shrink-0 text-brand"
          aria-hidden
        />
        <div className="flex-1">
          <div className="font-medium">
            {title}
            {metaParts.length > 0 && (
              <span className="font-normal text-muted-foreground">
                {" — "}
                {metaParts.join(" · ")}
              </span>
            )}
          </div>
          {summary && <div className="text-muted-foreground">{summary}</div>}
        </div>
      </div>
      {result.versionId && (
        <Button
          type="button"
          size="sm"
          variant="outline"
          className="h-7 w-fit px-3 text-xs"
          onClick={() => onOpen(result.versionId!, null)}
        >
          Abrir
        </Button>
      )}
    </div>
  )
}

function UpdateWorkoutCard({
  toolCall,
  onOpen,
}: {
  toolCall: ToolCall
  onOpen: OpenDrawer
}) {
  const result = (toolCall.result ?? {}) as UpdateWorkoutResult
  const args = (toolCall.arguments ?? {}) as {
    summaryMd?: string
    name?: string
  }
  const summary =
    (result.summaryMd && result.summaryMd.trim()) ||
    (args.summaryMd && args.summaryMd.trim()) ||
    null
  const workoutName =
    result.workoutName || (args.name && args.name.trim()) || "treino"

  if (result.error) {
    return (
      <div className="flex items-start gap-2 rounded-xl border border-destructive/40 bg-destructive/5 px-3 py-2 text-xs text-destructive">
        <Dumbbell className="mt-0.5 size-3.5 shrink-0" aria-hidden />
        <span>Falha ao atualizar treino: {result.error}</span>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-2 rounded-xl border border-brand/30 bg-brand/5 px-3 py-2.5 text-xs text-foreground">
      <div className="flex items-start gap-2">
        <Dumbbell className="mt-0.5 size-3.5 shrink-0 text-brand" aria-hidden />
        <div className="flex-1">
          <div className="font-medium">
            Treino <span className="font-semibold">{workoutName}</span>{" "}
            atualizado
          </div>
          {summary && <div className="text-muted-foreground">{summary}</div>}
        </div>
      </div>
      {result.versionId && result.workoutId && (
        <Button
          type="button"
          size="sm"
          variant="outline"
          className="h-7 w-fit px-3 text-xs"
          onClick={() => onOpen(result.versionId!, result.workoutId!)}
        >
          Abrir
        </Button>
      )}
    </div>
  )
}

function LiveMessageBubble({ live }: { live: LiveMessage }) {
  const hasContent = live.content.trim().length > 0
  return (
    <li className="flex flex-col items-start gap-1">
      {hasContent ? (
        <div className="max-w-[85%] rounded-2xl rounded-bl-sm bg-muted px-4 py-2.5 text-sm leading-relaxed text-foreground sm:max-w-[75%]">
          <Markdown content={live.content} className="text-sm" />
          <span className="ml-1 inline-block size-1.5 animate-pulse rounded-full bg-muted-foreground/60" aria-hidden />
        </div>
      ) : (
        <div className="flex max-w-[85%] items-center gap-2 rounded-2xl rounded-bl-sm bg-muted px-4 py-2.5 text-xs text-muted-foreground sm:max-w-[75%]">
          <Loader2 className="size-3.5 animate-spin" aria-hidden />
          Pensando…
        </div>
      )}
      {live.toolCalls.length > 0 && (
        <div className="flex w-full max-w-[85%] flex-col gap-1.5 sm:max-w-[75%]">
          {live.toolCalls.map((tc) => (
            <LiveToolCallCard key={tc.toolCallId} toolCall={tc} />
          ))}
        </div>
      )}
    </li>
  )
}

function LiveToolCallCard({ toolCall }: { toolCall: ToolCallEvent }) {
  const label = humanToolLabel(toolCall.name, toolCall.status)
  const Icon =
    toolCall.name === "update_anamnesis"
      ? FileText
      : toolCall.name === "update_workout"
        ? Dumbbell
        : CalendarRange
  return (
    <div className="flex items-center gap-2 rounded-xl border border-brand/30 bg-brand/5 px-3 py-2 text-xs text-foreground">
      <Icon className="size-3.5 shrink-0 text-brand" aria-hidden />
      <span className="flex-1">{label}</span>
      {toolCall.status === "running" ? (
        <Loader2 className="size-3.5 animate-spin text-brand" aria-hidden />
      ) : null}
    </div>
  )
}

function humanToolLabel(name: string, status: ToolCallEvent["status"]): string {
  const verb = status === "running" ? "…" : " concluído"
  switch (name) {
    case "update_anamnesis":
      return `Atualizando anamnese${verb}`
    case "create_periodization":
      return `Criando periodização${verb}`
    case "update_periodization":
      return `Atualizando periodização${verb}`
    case "update_workout":
      return `Atualizando treino${verb}`
    default:
      return `${name}${verb}`
  }
}

function ThinkingBubble() {
  return (
    <li className="flex flex-col items-start gap-1">
      <div className="flex max-w-[85%] items-center gap-2 rounded-2xl rounded-bl-sm bg-muted px-4 py-2.5 text-xs text-muted-foreground sm:max-w-[75%]">
        <Loader2 className="size-3.5 animate-spin" aria-hidden />
        O assistente está respondendo…
      </div>
    </li>
  )
}

function ErrorBubble({ error, onDismiss }: { error: string; onDismiss: () => void }) {
  return (
    <div className="mx-auto mt-4 flex max-w-3xl items-start gap-2 rounded-xl border border-destructive/40 bg-destructive/5 px-3 py-2 text-xs text-destructive">
      <AlertCircle className="mt-0.5 size-3.5 shrink-0" aria-hidden />
      <span className="flex-1">{error}</span>
      <button
        type="button"
        onClick={onDismiss}
        className="-mr-1 rounded-md p-1 text-destructive/80 hover:bg-destructive/10"
        aria-label="Fechar erro"
      >
        <X className="size-3.5" aria-hidden />
      </button>
    </div>
  )
}

function EmptyState({ studentName }: { studentName: string }) {
  return (
    <div className="mx-auto flex max-w-3xl flex-col items-start gap-3">
      <div className="max-w-[85%] rounded-2xl rounded-bl-sm bg-muted px-4 py-2.5 text-sm leading-relaxed sm:max-w-[75%]">
        Olá! Posso atualizar a anamnese do(a) {studentName}, criar uma
        periodização nova, revisar a ativa, ou editar um treino específico —
        é só me contar o que precisa. Você pode mandar texto, áudio, fotos ou
        PDFs.
      </div>
    </div>
  )
}

type Suggestion = {
  key: string
  label: string
  prefill: string
}

function buildSuggestions(
  studentName: string,
  hasActivePeriodization: boolean,
  workouts: SuggestionWorkout[],
): Suggestion[] {
  const suggestions: Suggestion[] = []
  if (!hasActivePeriodization) {
    suggestions.push({
      key: "create-periodization",
      label: "Criar periodização",
      prefill: `Crie uma periodização para ${studentName}: `,
    })
  }
  suggestions.push({
    key: "update-anamnesis",
    label: "Atualizar anamnese",
    prefill: "Atualize a anamnese: ",
  })
  for (const workout of workouts.slice(0, 3)) {
    suggestions.push({
      key: `edit-workout-${workout.id}`,
      label: `Editar Treino ${workout.name}`,
      prefill: `No Treino ${workout.name}, `,
    })
  }
  return suggestions
}

function SuggestionChips({
  studentName,
  hasActivePeriodization,
  workouts,
  onPrefill,
}: {
  studentName: string
  hasActivePeriodization: boolean
  workouts: SuggestionWorkout[]
  onPrefill: (text: string) => void
}) {
  const suggestions = buildSuggestions(studentName, hasActivePeriodization, workouts)
  if (suggestions.length === 0) return null
  return (
    <div className="mx-auto flex w-full max-w-3xl flex-wrap gap-1.5">
      {suggestions.map((s) => (
        <button
          key={s.key}
          type="button"
          onClick={() => onPrefill(s.prefill)}
          className="inline-flex items-center gap-1.5 rounded-full border border-brand/30 bg-brand/5 px-3 py-1 text-xs font-medium text-foreground transition hover:bg-brand/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          <Sparkles className="size-3 text-brand" aria-hidden />
          {s.label}
        </button>
      ))}
    </div>
  )
}

type PendingAttachment = {
  uid: string
  file: File
  kind: AttachmentKind
  previewUrl: string
  durationSec?: number
}

function classifyFile(file: File): AttachmentKind {
  const type = file.type
  if (type.startsWith("audio/")) return "audio"
  if (type.startsWith("image/")) return "image"
  if (type === "application/pdf") return "pdf"
  return "file"
}

function preferredAudioMimeType(): string {
  const candidates = [
    "audio/webm;codecs=opus",
    "audio/webm",
    "audio/mp4",
    "audio/ogg;codecs=opus",
  ]
  for (const candidate of candidates) {
    if (
      typeof MediaRecorder !== "undefined" &&
      MediaRecorder.isTypeSupported(candidate)
    ) {
      return candidate
    }
  }
  return ""
}

function extensionForMime(mime: string): string {
  if (mime.startsWith("audio/webm")) return "webm"
  if (mime.startsWith("audio/mp4")) return "m4a"
  if (mime.startsWith("audio/ogg")) return "ogg"
  return "webm"
}

function Composer({
  studentId,
  disabled,
  content,
  onContentChange,
  textareaRef,
  suggestionChips,
}: {
  studentId: string
  disabled: boolean
  content: string
  onContentChange: (value: string) => void
  textareaRef: React.RefObject<HTMLTextAreaElement | null>
  suggestionChips: React.ReactNode
}) {
  const [submitting, setSubmitting] = useState(false)
  const [pending, setPending] = useState<PendingAttachment[]>([])
  const [micError, setMicError] = useState<string | null>(null)
  const [isRecording, setIsRecording] = useState(false)
  const [recordingMs, setRecordingMs] = useState(0)
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const cameraInputRef = useRef<HTMLInputElement | null>(null)
  const recorderRef = useRef<MediaRecorder | null>(null)
  const recordedChunksRef = useRef<Blob[]>([])
  const recordingStartRef = useRef<number>(0)
  const recordingTimerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const mediaStreamRef = useRef<MediaStream | null>(null)

  // Revoke any remaining object URLs on unmount.
  useEffect(() => {
    return () => {
      pending.forEach((p) => URL.revokeObjectURL(p.previewUrl))
      if (recordingTimerRef.current != null) {
        clearInterval(recordingTimerRef.current)
      }
      mediaStreamRef.current?.getTracks().forEach((t) => t.stop())
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function addFiles(files: FileList | File[]) {
    const incoming = Array.from(files)
    setPending((prev) => {
      const room = MAX_ATTACHMENT_COUNT - prev.length
      if (room <= 0) return prev
      const accepted: PendingAttachment[] = []
      for (const file of incoming.slice(0, room)) {
        if (file.size > MAX_ATTACHMENT_BYTES) continue
        accepted.push({
          uid: cryptoRandomId(),
          file,
          kind: classifyFile(file),
          previewUrl: URL.createObjectURL(file),
        })
      }
      return [ ...prev, ...accepted ]
    })
  }

  function removePending(uid: string) {
    setPending((prev) => {
      const next = prev.filter((p) => p.uid !== uid)
      const removed = prev.find((p) => p.uid === uid)
      if (removed) URL.revokeObjectURL(removed.previewUrl)
      return next
    })
  }

  function resetComposer() {
    pending.forEach((p) => URL.revokeObjectURL(p.previewUrl))
    setPending([])
    onContentChange("")
  }

  async function startRecording() {
    if (isRecording) return
    setMicError(null)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      mediaStreamRef.current = stream
      const mimeType = preferredAudioMimeType()
      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream)
      recordedChunksRef.current = []
      recorder.addEventListener("dataavailable", (event) => {
        if (event.data && event.data.size > 0) {
          recordedChunksRef.current.push(event.data)
        }
      })
      recorder.addEventListener("stop", () => {
        const effectiveMime = recorder.mimeType || mimeType || "audio/webm"
        const blob = new Blob(recordedChunksRef.current, { type: effectiveMime })
        const ext = extensionForMime(effectiveMime)
        const filename = `gravacao-${Date.now()}.${ext}`
        const file = new File([ blob ], filename, { type: effectiveMime })
        const durationSec = Math.max(1, Math.round((Date.now() - recordingStartRef.current) / 1000))
        setPending((prev) => {
          if (prev.length >= MAX_ATTACHMENT_COUNT) return prev
          return [
            ...prev,
            {
              uid: cryptoRandomId(),
              file,
              kind: "audio",
              previewUrl: URL.createObjectURL(file),
              durationSec,
            },
          ]
        })
        stream.getTracks().forEach((t) => t.stop())
        mediaStreamRef.current = null
        recordedChunksRef.current = []
      })
      recorder.start()
      recorderRef.current = recorder
      recordingStartRef.current = Date.now()
      setRecordingMs(0)
      setIsRecording(true)
      recordingTimerRef.current = setInterval(() => {
        setRecordingMs(Date.now() - recordingStartRef.current)
      }, 250)
    } catch (err) {
      const message =
        err instanceof Error && err.name === "NotAllowedError"
          ? "Permissão de microfone negada. Habilite o microfone nas configurações do navegador para gravar áudio."
          : "Não foi possível acessar o microfone. Verifique as permissões do navegador."
      setMicError(message)
      mediaStreamRef.current?.getTracks().forEach((t) => t.stop())
      mediaStreamRef.current = null
    }
  }

  function stopRecording() {
    const recorder = recorderRef.current
    if (recorder && recorder.state !== "inactive") recorder.stop()
    recorderRef.current = null
    setIsRecording(false)
    if (recordingTimerRef.current != null) {
      clearInterval(recordingTimerRef.current)
      recordingTimerRef.current = null
    }
  }

  function toggleRecording() {
    if (isRecording) stopRecording()
    else startRecording()
  }

  function handleSubmit(event?: React.FormEvent) {
    event?.preventDefault()
    if (disabled || submitting) return
    if (isRecording) return
    const trimmed = content.trim()
    if (trimmed.length === 0 && pending.length === 0) return

    setSubmitting(true)
    router.post(
      `/students/${studentId}/agent_chat/messages`,
      {
        message: {
          content: trimmed,
          attachments: pending.map((p) => p.file),
        },
      },
      {
        forceFormData: true,
        preserveScroll: false,
        onSuccess: () => resetComposer(),
        onFinish: () => setSubmitting(false),
      },
    )
  }

  function handleKeyDown(event: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      handleSubmit()
    }
  }

  const busy = disabled || submitting
  const canSend =
    (content.trim().length > 0 || pending.length > 0) && !busy && !isRecording
  const roomLeft = MAX_ATTACHMENT_COUNT - pending.length

  return (
    <form
      onSubmit={handleSubmit}
      className="sticky bottom-0 z-10 flex flex-col gap-2 border-t border-border/60 bg-background/95 px-4 py-3 backdrop-blur sm:px-6"
      style={{
        paddingBottom: "max(0.75rem, env(safe-area-inset-bottom))",
      }}
    >
      <input
        ref={fileInputRef}
        type="file"
        multiple
        accept="application/pdf,image/*,audio/*"
        className="hidden"
        onChange={(event) => {
          if (event.target.files) addFiles(event.target.files)
          event.target.value = ""
        }}
      />
      <input
        ref={cameraInputRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={(event) => {
          if (event.target.files) addFiles(event.target.files)
          event.target.value = ""
        }}
      />

      {suggestionChips}

      {pending.length > 0 && (
        <div className="mx-auto flex w-full max-w-3xl flex-wrap gap-1.5">
          {pending.map((p) => (
            <PendingChip key={p.uid} pending={p} onRemove={() => removePending(p.uid)} />
          ))}
        </div>
      )}

      {micError && (
        <div className="mx-auto flex w-full max-w-3xl items-start gap-2 rounded-xl border border-destructive/40 bg-destructive/5 px-3 py-2 text-xs text-destructive">
          <AlertCircle className="mt-0.5 size-3.5 shrink-0" aria-hidden />
          <span className="flex-1">{micError}</span>
          <button
            type="button"
            onClick={() => setMicError(null)}
            className="-mr-1 rounded-md p-1 text-destructive/80 hover:bg-destructive/10"
            aria-label="Fechar aviso"
          >
            <X className="size-3.5" aria-hidden />
          </button>
        </div>
      )}

      {isRecording && (
        <div className="mx-auto flex w-full max-w-3xl items-center gap-2 rounded-xl border border-destructive/40 bg-destructive/5 px-3 py-2 text-xs text-destructive">
          <span className="relative flex size-2.5 shrink-0" aria-hidden>
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-destructive opacity-75" />
            <span className="relative inline-flex size-2.5 rounded-full bg-destructive" />
          </span>
          <span className="flex-1">Gravando… {formatRecordingTime(recordingMs)}</span>
          <button
            type="button"
            onClick={stopRecording}
            className="rounded-md bg-destructive px-2 py-0.5 text-[11px] font-medium text-destructive-foreground"
          >
            Parar
          </button>
        </div>
      )}

      <div className="mx-auto flex w-full max-w-3xl items-end gap-1.5">
        <Button
          type="button"
          size="icon"
          variant="ghost"
          disabled={busy || isRecording || roomLeft <= 0}
          aria-label="Anexar arquivo"
          className="size-10 shrink-0"
          onClick={() => fileInputRef.current?.click()}
        >
          <Paperclip className="size-4" aria-hidden />
        </Button>
        <Button
          type="button"
          size="icon"
          variant="ghost"
          disabled={busy || isRecording || roomLeft <= 0}
          aria-label="Tirar foto"
          className="size-10 shrink-0"
          onClick={() => cameraInputRef.current?.click()}
        >
          <Camera className="size-4" aria-hidden />
        </Button>
        <Button
          type="button"
          size="icon"
          variant={isRecording ? "destructive" : "ghost"}
          disabled={busy || (!isRecording && roomLeft <= 0)}
          aria-label={isRecording ? "Parar gravação" : "Gravar áudio"}
          aria-pressed={isRecording}
          className="size-10 shrink-0"
          onClick={toggleRecording}
        >
          {isRecording ? (
            <Square className="size-4" aria-hidden />
          ) : (
            <Mic className="size-4" aria-hidden />
          )}
        </Button>
        <Textarea
          ref={textareaRef}
          value={content}
          onChange={(event) => onContentChange(event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={
            busy
              ? "Aguardando resposta do assistente…"
              : isRecording
                ? "Gravando áudio…"
                : "Conte o que houve, anexe arquivos ou grave um áudio."
          }
          rows={2}
          disabled={busy || isRecording}
          className="min-h-[44px] resize-none"
        />
        <Button
          type="submit"
          size="icon"
          disabled={!canSend}
          aria-label="Enviar mensagem"
          className="size-11 shrink-0"
        >
          {submitting ? (
            <Loader2 className="size-4 animate-spin" aria-hidden />
          ) : (
            <Send className="size-4" aria-hidden />
          )}
        </Button>
      </div>
    </form>
  )
}

function PendingChip({
  pending,
  onRemove,
}: {
  pending: PendingAttachment
  onRemove: () => void
}) {
  if (pending.kind === "image") {
    return (
      <div className="group relative overflow-hidden rounded-xl border border-border bg-muted/40">
        <img
          src={pending.previewUrl}
          alt={pending.file.name}
          className="block size-16 object-cover"
        />
        <RemoveButton onRemove={onRemove} />
      </div>
    )
  }

  if (pending.kind === "audio") {
    return (
      <div className="relative flex items-center gap-2 rounded-xl border border-border bg-muted/40 px-3 py-2 pr-8 text-xs">
        <AudioPreviewButton url={pending.previewUrl} />
        <span className="font-medium">
          {pending.durationSec != null
            ? formatDuration(pending.durationSec)
            : pending.file.name}
        </span>
        <RemoveButton onRemove={onRemove} />
      </div>
    )
  }

  return (
    <div className="relative flex items-center gap-2 rounded-xl border border-border bg-muted/40 px-3 py-2 pr-8 text-xs">
      <FileText className="size-3.5 text-muted-foreground" aria-hidden />
      <div className="flex min-w-0 flex-col">
        <span className="truncate font-medium max-w-[160px]">{pending.file.name}</span>
        <span className="text-muted-foreground">{formatBytes(pending.file.size)}</span>
      </div>
      <RemoveButton onRemove={onRemove} />
    </div>
  )
}

function AudioPreviewButton({ url }: { url: string }) {
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const [playing, setPlaying] = useState(false)

  useEffect(() => {
    const audio = audioRef.current
    if (!audio) return
    const handleEnded = () => setPlaying(false)
    audio.addEventListener("ended", handleEnded)
    return () => audio.removeEventListener("ended", handleEnded)
  }, [])

  function toggle() {
    const audio = audioRef.current
    if (!audio) return
    if (playing) {
      audio.pause()
      setPlaying(false)
    } else {
      audio.currentTime = 0
      void audio.play().then(() => setPlaying(true)).catch(() => setPlaying(false))
    }
  }

  return (
    <>
      <button
        type="button"
        onClick={toggle}
        className="flex size-6 items-center justify-center rounded-full bg-brand/15 text-brand"
        aria-label={playing ? "Pausar prévia" : "Reproduzir prévia"}
      >
        {playing ? <Square className="size-3" aria-hidden /> : <Play className="size-3" aria-hidden />}
      </button>
      <audio ref={audioRef} src={url} preload="metadata" />
    </>
  )
}

function RemoveButton({ onRemove }: { onRemove: () => void }) {
  return (
    <button
      type="button"
      onClick={onRemove}
      className="absolute right-1 top-1 flex size-5 items-center justify-center rounded-full bg-background/80 text-foreground/80 hover:bg-background"
      aria-label="Remover anexo"
    >
      <X className="size-3" aria-hidden />
    </button>
  )
}

function Lightbox({ url, onClose }: { url: string; onClose: () => void }) {
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose()
    }
    document.addEventListener("keydown", onKey)
    return () => document.removeEventListener("keydown", onKey)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
    >
      <img
        src={url}
        alt=""
        className="max-h-full max-w-full object-contain"
        onClick={(e) => e.stopPropagation()}
      />
      <button
        type="button"
        onClick={onClose}
        className="absolute right-4 top-4 flex size-10 items-center justify-center rounded-full bg-background/80 text-foreground"
        aria-label="Fechar"
      >
        <X className="size-5" aria-hidden />
      </button>
    </div>
  )
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function formatDuration(sec: number): string {
  const m = Math.floor(sec / 60)
  const s = sec % 60
  return `${m}:${s.toString().padStart(2, "0")}`
}

function formatRecordingTime(ms: number): string {
  return formatDuration(Math.floor(ms / 1000))
}

function cryptoRandomId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID()
  }
  return Math.random().toString(36).slice(2)
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/)
  if (parts.length === 0) return "?"
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}
