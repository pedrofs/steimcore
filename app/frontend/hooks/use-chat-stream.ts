import { router } from "@inertiajs/react"
import { createConsumer, type Consumer, type Subscription } from "@rails/actioncable"
import { useEffect, useRef, useState } from "react"

export type ToolCallEvent = {
  toolCallId: string
  name: string
  status: "running" | "completed"
  result?: Record<string, unknown> | null
}

export type LiveMessage = {
  id: string | null
  role: "assistant"
  content: string
  toolCalls: ToolCallEvent[]
}

type RawChunkEvent = { type: "chunk"; message_id?: string | null; delta: string }
type RawToolStartedEvent = {
  type: "tool_call_started"
  message_id?: string | null
  tool_call_id: string
  name: string
}
type RawToolCompletedEvent = {
  type: "tool_call_completed"
  tool_call_id: string
  result: Record<string, unknown> | null
}
type RawTurnCompletedEvent = { type: "turn_completed"; message_id?: string | null }
type RawTurnFailedEvent = { type: "turn_failed"; error: string }

type RawEvent =
  | RawChunkEvent
  | RawToolStartedEvent
  | RawToolCompletedEvent
  | RawTurnCompletedEvent
  | RawTurnFailedEvent

type Options = {
  reloadProps?: string[]
}

let consumer: Consumer | null = null
function getConsumer(): Consumer {
  if (consumer == null) {
    consumer = createConsumer()
  }
  return consumer
}

const EMPTY_LIVE: LiveMessage = {
  id: null,
  role: "assistant",
  content: "",
  toolCalls: [],
}

export function useChatStream(chatId: string, options: Options = {}) {
  const [ liveMessage, setLiveMessage ] = useState<LiveMessage | null>(null)
  const [ error, setError ] = useState<string | null>(null)
  const reloadProps = options.reloadProps ?? [ "messages" ]
  const reloadPropsRef = useRef(reloadProps)
  reloadPropsRef.current = reloadProps

  useEffect(() => {
    let subscription: Subscription | null = null
    let cancelled = false

    const handleEvent = (raw: unknown) => {
      if (cancelled) return
      if (!isRawEvent(raw)) return
      handleStreamEvent(raw, setLiveMessage, setError, reloadPropsRef.current)
    }

    subscription = getConsumer().subscriptions.create(
      { channel: "Agent::ChatChannel", chat_id: chatId },
      { received: handleEvent },
    )

    return () => {
      cancelled = true
      subscription?.unsubscribe()
    }
  }, [ chatId ])

  return {
    liveMessage,
    error,
    clearError: () => setError(null),
  }
}

function handleStreamEvent(
  raw: RawEvent,
  setLiveMessage: React.Dispatch<React.SetStateAction<LiveMessage | null>>,
  setError: React.Dispatch<React.SetStateAction<string | null>>,
  reloadProps: string[],
) {
  switch (raw.type) {
    case "chunk":
      setLiveMessage((prev) => {
        const base = prev ?? { ...EMPTY_LIVE }
        return {
          ...base,
          id: base.id ?? raw.message_id ?? null,
          content: base.content + raw.delta,
        }
      })
      return

    case "tool_call_started":
      setLiveMessage((prev) => {
        const base = prev ?? { ...EMPTY_LIVE }
        return {
          ...base,
          id: base.id ?? raw.message_id ?? null,
          toolCalls: [
            ...base.toolCalls,
            { toolCallId: raw.tool_call_id, name: raw.name, status: "running" },
          ],
        }
      })
      return

    case "tool_call_completed":
      setLiveMessage((prev) => {
        if (prev == null) return prev
        return {
          ...prev,
          toolCalls: prev.toolCalls.map((tc) =>
            tc.toolCallId === raw.tool_call_id
              ? { ...tc, status: "completed", result: raw.result }
              : tc,
          ),
        }
      })
      return

    case "turn_completed":
      router.reload({
        only: reloadProps,
        onFinish: () => setLiveMessage(null),
      })
      return

    case "turn_failed":
      setError(raw.error)
      setLiveMessage(null)
      router.reload({ only: reloadProps })
      return
  }
}

function isRawEvent(value: unknown): value is RawEvent {
  if (typeof value !== "object" || value === null) return false
  const t = (value as { type?: unknown }).type
  return (
    t === "chunk" ||
    t === "tool_call_started" ||
    t === "tool_call_completed" ||
    t === "turn_completed" ||
    t === "turn_failed"
  )
}
