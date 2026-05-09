import { router } from "@inertiajs/react"
import { useEffect, useRef } from "react"

const TERMINAL_STATUSES = new Set(["completed", "failed"])
const POLL_INTERVAL_MS = 2000

export function useJobStatus(status: string, propsToRefresh: string[]) {
  const isTerminal = TERMINAL_STATUSES.has(status)
  const propsRef = useRef(propsToRefresh)
  propsRef.current = propsToRefresh

  useEffect(() => {
    if (isTerminal) return
    if (typeof document === "undefined") return

    let timer: number | null = null

    const tick = () => {
      if (document.hidden) return
      router.reload({ only: propsRef.current as never[] })
    }

    timer = window.setInterval(tick, POLL_INTERVAL_MS)

    const onVisibilityChange = () => {
      if (!document.hidden) tick()
    }
    document.addEventListener("visibilitychange", onVisibilityChange)

    return () => {
      if (timer != null) window.clearInterval(timer)
      document.removeEventListener("visibilitychange", onVisibilityChange)
    }
  }, [isTerminal])
}
