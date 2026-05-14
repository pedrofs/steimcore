import { Link, router } from "@inertiajs/react"
import {
  ArrowLeft,
  CalendarRange,
  Dumbbell,
  FileText,
  Loader2,
  Send,
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

type Message = {
  id: string
  role: "user" | "assistant" | "tool" | "system"
  content: string | null
  createdAt: string
  trainerEmailPrefix: string | null
  toolCalls: ToolCall[]
}

type Props = {
  student: Student
  chat: Chat
  messages: Message[]
  openVersion: PeriodizationVersionData | null
}

type DrawerState = {
  open: boolean
  versionId: string | null
  workoutId: string | null
}

export default function AgentChatShow({
  student,
  chat,
  messages,
  openVersion,
}: Props) {
  const visibleMessages = useMemo(
    () => messages.filter((m) => m.role !== "tool" && m.role !== "system"),
    [messages],
  )

  const scrollRef = useRef<HTMLDivElement | null>(null)
  useEffect(() => {
    const el = scrollRef.current
    if (!el) return
    el.scrollTop = el.scrollHeight
  }, [visibleMessages.length])

  const [drawerState, setDrawerState] = useState<DrawerState>({
    open: false,
    versionId: null,
    workoutId: null,
  })

  const chatPath = `/students/${student.id}/agent_chat`

  const refreshOpenVersion = useCallback(
    (versionId: string | null, opts: { replace?: boolean } = {}) => {
      router.reload({
        only: [ "open_version" ],
        data: versionId
          ? { open_version_id: versionId }
          : { open_version_id: undefined },
        preserveScroll: true,
        preserveState: true,
        replace: opts.replace ?? false,
      })
    },
    [],
  )

  const openDrawer = useCallback(
    (versionId: string, workoutId: string | null) => {
      setDrawerState({ open: true, versionId, workoutId })
      // replace: false so the browser back button (device back on mobile)
      // pops the drawer open_version_id off the URL, which then drives the
      // drawer-close effect below.
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

  // Close the drawer when the open_version_id is removed from the URL by an
  // external navigation — e.g., the user tapping the device back button on
  // mobile or following a link inside the drawer that returns without the
  // param. We only fire after the prop has first been populated so the very
  // first render (before the open request completes) doesn't slam the
  // drawer shut.
  const sawOpenVersionRef = useRef(false)
  useEffect(() => {
    if (openVersion != null) {
      sawOpenVersionRef.current = true
      return
    }
    if (sawOpenVersionRef.current && drawerState.open) {
      setDrawerState({ open: false, versionId: null, workoutId: null })
      sawOpenVersionRef.current = false
    }
  }, [openVersion, drawerState.open])

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
    <div className="flex h-[100dvh] flex-col bg-background">
      <ChatHeader student={student} />

      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto px-4 py-4 sm:px-6"
        aria-live="polite"
      >
        {visibleMessages.length === 0 ? (
          <EmptyState studentName={student.name} />
        ) : (
          <ol className="mx-auto flex max-w-3xl flex-col gap-4">
            {visibleMessages.map((message) => (
              <MessageBubble key={message.id} message={message} onOpen={openDrawer} />
            ))}
          </ol>
        )}
      </div>

      <Composer studentId={student.id} disabled={chat.state === "running"} />

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

function MessageBubble({
  message,
  onOpen,
}: {
  message: Message
  onOpen: OpenDrawer
}) {
  const isTrainer = message.role === "user"
  return (
    <li
      className={cn(
        "flex flex-col gap-1",
        isTrainer ? "items-end" : "items-start",
      )}
    >
      {message.content && message.content.trim().length > 0 && (
        <div
          className={cn(
            "max-w-[85%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed sm:max-w-[75%]",
            isTrainer
              ? "rounded-br-sm bg-brand text-brand-foreground"
              : "rounded-bl-sm bg-muted text-foreground",
          )}
        >
          <Markdown content={message.content} className="text-sm" />
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

function EmptyState({ studentName }: { studentName: string }) {
  return (
    <div className="mx-auto flex max-w-3xl flex-col items-start gap-3">
      <div className="max-w-[85%] rounded-2xl rounded-bl-sm bg-muted px-4 py-2.5 text-sm leading-relaxed sm:max-w-[75%]">
        Olá! Posso atualizar a anamnese do(a) {studentName}, criar uma
        periodização nova, revisar a ativa, ou editar um treino específico —
        é só me contar o que precisa.
      </div>
    </div>
  )
}

function Composer({
  studentId,
  disabled,
}: {
  studentId: string
  disabled: boolean
}) {
  const [content, setContent] = useState("")
  const [submitting, setSubmitting] = useState(false)
  const textareaRef = useRef<HTMLTextAreaElement | null>(null)

  function handleSubmit(event?: React.FormEvent) {
    event?.preventDefault()
    const trimmed = content.trim()
    if (trimmed.length === 0 || disabled || submitting) return

    setSubmitting(true)
    router.post(
      `/students/${studentId}/agent_chat/messages`,
      { message: { content: trimmed } },
      {
        preserveScroll: false,
        onSuccess: () => setContent(""),
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
  const canSend = content.trim().length > 0 && !busy

  return (
    <form
      onSubmit={handleSubmit}
      className="sticky bottom-0 z-10 border-t border-border/60 bg-background/95 px-4 py-3 backdrop-blur sm:px-6"
      style={{
        paddingBottom: "max(0.75rem, env(safe-area-inset-bottom))",
      }}
    >
      <div className="mx-auto flex max-w-3xl items-end gap-2">
        <Textarea
          ref={textareaRef}
          value={content}
          onChange={(event) => setContent(event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={
            busy
              ? "Aguardando resposta do assistente…"
              : "Conte o que houve. Ex.: atualize a anamnese para incluir lesão no joelho direito."
          }
          rows={2}
          disabled={busy}
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

function initials(name: string): string {
  const parts = name.trim().split(/\s+/)
  if (parts.length === 0) return "?"
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}
