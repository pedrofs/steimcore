import { useCallback, useEffect, useRef, useState } from "react"

const MAX_DURATION_MS = 3 * 60 * 1000

export type RecorderState = "idle" | "recording" | "stopped" | "error"

export type RecordedAudio = {
  blob: Blob
  durationMs: number
  mimeType: string
}

export type UseVoiceRecorder = {
  state: RecorderState
  errorMessage: string | null
  elapsedMs: number
  remainingMs: number
  audio: RecordedAudio | null
  start: () => Promise<void>
  stop: () => void
  reset: () => void
}

const PREFERRED_MIME_TYPES = [
  "audio/webm;codecs=opus",
  "audio/webm",
  "audio/mp4",
  "audio/ogg;codecs=opus",
]

function pickMimeType(): string {
  if (typeof MediaRecorder === "undefined") return ""
  for (const type of PREFERRED_MIME_TYPES) {
    if (MediaRecorder.isTypeSupported(type)) return type
  }
  return ""
}

export function useVoiceRecorder(): UseVoiceRecorder {
  const [state, setState] = useState<RecorderState>("idle")
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [elapsedMs, setElapsedMs] = useState(0)
  const [audio, setAudio] = useState<RecordedAudio | null>(null)

  const recorderRef = useRef<MediaRecorder | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const chunksRef = useRef<Blob[]>([])
  const startTimeRef = useRef<number>(0)
  const tickRef = useRef<number | null>(null)
  const stopTimerRef = useRef<number | null>(null)

  const cleanupTimers = useCallback(() => {
    if (tickRef.current != null) {
      window.clearInterval(tickRef.current)
      tickRef.current = null
    }
    if (stopTimerRef.current != null) {
      window.clearTimeout(stopTimerRef.current)
      stopTimerRef.current = null
    }
  }, [])

  const releaseStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((track) => track.stop())
    streamRef.current = null
  }, [])

  const reset = useCallback(() => {
    cleanupTimers()
    releaseStream()
    recorderRef.current = null
    chunksRef.current = []
    setState("idle")
    setErrorMessage(null)
    setElapsedMs(0)
    setAudio(null)
  }, [cleanupTimers, releaseStream])

  useEffect(() => {
    return () => {
      cleanupTimers()
      releaseStream()
    }
  }, [cleanupTimers, releaseStream])

  const stop = useCallback(() => {
    const recorder = recorderRef.current
    if (recorder && recorder.state !== "inactive") {
      recorder.stop()
    }
  }, [])

  const start = useCallback(async () => {
    setErrorMessage(null)
    setAudio(null)
    setElapsedMs(0)

    if (typeof navigator === "undefined" || !navigator.mediaDevices?.getUserMedia) {
      setState("error")
      setErrorMessage("Este navegador não suporta gravação de áudio.")
      return
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.current = stream

      const mimeType = pickMimeType()
      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream)
      recorderRef.current = recorder
      chunksRef.current = []

      recorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) chunksRef.current.push(event.data)
      }

      recorder.onstop = () => {
        const finalMime = recorder.mimeType || mimeType || "audio/webm"
        const blob = new Blob(chunksRef.current, { type: finalMime })
        const durationMs = Date.now() - startTimeRef.current
        setAudio({ blob, durationMs, mimeType: finalMime })
        setState("stopped")
        cleanupTimers()
        releaseStream()
      }

      recorder.onerror = (event) => {
        setState("error")
        const error = (event as unknown as { error?: { message?: string } }).error
        setErrorMessage(error?.message ?? "Falha durante a gravação.")
        cleanupTimers()
        releaseStream()
      }

      startTimeRef.current = Date.now()
      recorder.start()
      setState("recording")

      tickRef.current = window.setInterval(() => {
        setElapsedMs(Date.now() - startTimeRef.current)
      }, 250)

      stopTimerRef.current = window.setTimeout(() => {
        if (recorderRef.current && recorderRef.current.state !== "inactive") {
          recorderRef.current.stop()
        }
      }, MAX_DURATION_MS)
    } catch (err) {
      setState("error")
      const message =
        err instanceof DOMException && err.name === "NotAllowedError"
          ? "Permissão de microfone negada. Habilite o acesso para gravar."
          : err instanceof Error
            ? err.message
            : "Não foi possível iniciar a gravação."
      setErrorMessage(message)
      releaseStream()
    }
  }, [cleanupTimers, releaseStream])

  return {
    state,
    errorMessage,
    elapsedMs,
    remainingMs: Math.max(0, MAX_DURATION_MS - elapsedMs),
    audio,
    start,
    stop,
    reset,
  }
}

export const VOICE_RECORDER_MAX_MS = MAX_DURATION_MS
