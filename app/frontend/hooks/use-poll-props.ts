import { router } from "@inertiajs/react"
import { useEffect, useRef } from "react"

const DEFAULT_INTERVAL_MS = 3000

export function usePollProps(
  propsToRefresh: string[],
  options: { intervalMs?: number } = {},
) {
  const interval = options.intervalMs ?? DEFAULT_INTERVAL_MS
  const propsRef = useRef(propsToRefresh)
  propsRef.current = propsToRefresh

  useEffect(() => {
    if (typeof document === "undefined") return

    let timer: number | null = null

    const tick = () => {
      if (document.hidden) return
      router.reload({ only: propsRef.current as never[] })
    }

    timer = window.setInterval(tick, interval)

    const onVisibilityChange = () => {
      if (!document.hidden) tick()
    }
    document.addEventListener("visibilitychange", onVisibilityChange)

    return () => {
      if (timer != null) window.clearInterval(timer)
      document.removeEventListener("visibilitychange", onVisibilityChange)
    }
  }, [interval])
}
