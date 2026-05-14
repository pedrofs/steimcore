import { Link, router } from "@inertiajs/react"
import {
  ArrowLeft,
  CalendarRange,
  Dumbbell,
  FileText,
  Loader2,
  Send,
} from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"

import { Markdown } from "@/components/markdown"
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
}

export default function AgentChatShow({ student, chat, messages }: Props) {
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
              <MessageBubble key={message.id} message={message} />
            ))}
          </ol>
        )}
      </div>

      <Composer studentId={student.id} disabled={chat.state === "running"} />
    </div>
  )
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

function MessageBubble({ message }: { message: Message }) {
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
            <ToolCallCard key={tc.id} toolCall={tc} />
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

function ToolCallCard({ toolCall }: { toolCall: ToolCall }) {
  if (toolCall.name === "update_anamnesis") {
    return <UpdateAnamnesisCard toolCall={toolCall} />
  }
  if (
    toolCall.name === "create_periodization" ||
    toolCall.name === "update_periodization"
  ) {
    return <PeriodizationCard toolCall={toolCall} />
  }
  if (toolCall.name === "update_workout") {
    return <UpdateWorkoutCard toolCall={toolCall} />
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

function PeriodizationCard({ toolCall }: { toolCall: ToolCall }) {
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
          asChild
          size="sm"
          variant="outline"
          className="h-7 w-fit px-3 text-xs"
        >
          <Link href={`/periodization_versions/${result.versionId}`}>Abrir</Link>
        </Button>
      )}
    </div>
  )
}

function UpdateWorkoutCard({ toolCall }: { toolCall: ToolCall }) {
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
      {result.versionId && (
        <Button
          asChild
          size="sm"
          variant="outline"
          className="h-7 w-fit px-3 text-xs"
        >
          <Link href={`/periodization_versions/${result.versionId}`}>Abrir</Link>
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
