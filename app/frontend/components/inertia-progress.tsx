import { router } from "@inertiajs/react"
import { useEffect, useRef, useState } from "react"

const START_DELAY_MS = 80
const TRICKLE_INTERVAL_MS = 200
const FINISH_FADE_MS = 250

export function InertiaProgressBar() {
  const [visible, setVisible] = useState(false)
  const [percent, setPercent] = useState(0)
  const startTimer = useRef<number | undefined>(undefined)
  const trickleTimer = useRef<number | undefined>(undefined)
  const finishTimer = useRef<number | undefined>(undefined)

  useEffect(() => {
    const clearTimers = () => {
      if (startTimer.current) window.clearTimeout(startTimer.current)
      if (trickleTimer.current) window.clearInterval(trickleTimer.current)
      if (finishTimer.current) window.clearTimeout(finishTimer.current)
      startTimer.current = undefined
      trickleTimer.current = undefined
      finishTimer.current = undefined
    }

    const onStart = () => {
      clearTimers()
      startTimer.current = window.setTimeout(() => {
        setVisible(true)
        setPercent(20)
        trickleTimer.current = window.setInterval(() => {
          setPercent((p) => Math.min(p + (90 - p) * 0.12, 90))
        }, TRICKLE_INTERVAL_MS)
      }, START_DELAY_MS)
    }

    const onProgress = (event: {
      detail: { progress?: { percentage?: number } }
    }) => {
      const pct = event.detail.progress?.percentage
      if (typeof pct === "number") {
        setPercent(Math.max(20, pct * 0.9))
      }
    }

    const onFinish = () => {
      if (startTimer.current) {
        window.clearTimeout(startTimer.current)
        startTimer.current = undefined
      }
      if (trickleTimer.current) {
        window.clearInterval(trickleTimer.current)
        trickleTimer.current = undefined
      }
      setPercent(100)
      finishTimer.current = window.setTimeout(() => {
        setVisible(false)
        setPercent(0)
      }, FINISH_FADE_MS)
    }

    const removeStart = router.on("start", onStart)
    const removeProgress = router.on("progress", onProgress)
    const removeFinish = router.on("finish", onFinish)

    return () => {
      clearTimers()
      removeStart()
      removeProgress()
      removeFinish()
    }
  }, [])

  if (!visible) return null

  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-x-0 z-[100]"
      style={{ top: "env(safe-area-inset-top)" }}
    >
      <div
        className="h-[3px] bg-primary shadow-[0_0_8px_rgba(168,0,56,0.6)] transition-[width,opacity] duration-200 ease-out"
        style={{
          width: `${percent}%`,
          opacity: percent === 100 ? 0 : 1,
        }}
      />
    </div>
  )
}
