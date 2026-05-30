import { router } from "@inertiajs/react"
import { RefreshCw } from "lucide-react"
import { useEffect, useRef, useState } from "react"

import { cn } from "@/lib/utils"

const THRESHOLD = 72
const MAX_PULL = 120
const PULL_DAMPING = 0.5

function isStandalonePWA(): boolean {
  if (typeof window === "undefined") return false
  if (window.matchMedia?.("(display-mode: standalone)").matches) return true
  const nav = window.navigator as Navigator & { standalone?: boolean }
  return nav.standalone === true
}

export function PullToRefresh() {
  const [pullDistance, setPullDistance] = useState(0)
  const [refreshing, setRefreshing] = useState(false)
  const pullRef = useRef(0)
  const startY = useRef<number | null>(null)
  const active = useRef(false)

  useEffect(() => {
    if (!isStandalonePWA()) return

    const updatePull = (v: number) => {
      pullRef.current = v
      setPullDistance(v)
    }

    const onTouchStart = (e: TouchEvent) => {
      if (e.touches.length !== 1) return
      if (window.scrollY > 0) return
      if (refreshing) return
      startY.current = e.touches[0].clientY
      active.current = true
    }

    const onTouchMove = (e: TouchEvent) => {
      if (!active.current || startY.current === null) return
      if (window.scrollY > 0) {
        active.current = false
        updatePull(0)
        return
      }
      const dy = e.touches[0].clientY - startY.current
      if (dy <= 0) {
        updatePull(0)
        return
      }
      if (e.cancelable) e.preventDefault()
      updatePull(Math.min(dy * PULL_DAMPING, MAX_PULL))
    }

    const onTouchEnd = () => {
      if (!active.current) return
      active.current = false
      startY.current = null
      if (pullRef.current >= THRESHOLD) {
        setRefreshing(true)
        updatePull(THRESHOLD)
        router.reload({
          onFinish: () => {
            setRefreshing(false)
            updatePull(0)
          },
        })
      } else {
        updatePull(0)
      }
    }

    window.addEventListener("touchstart", onTouchStart, { passive: true })
    window.addEventListener("touchmove", onTouchMove, { passive: false })
    window.addEventListener("touchend", onTouchEnd)
    window.addEventListener("touchcancel", onTouchEnd)

    return () => {
      window.removeEventListener("touchstart", onTouchStart)
      window.removeEventListener("touchmove", onTouchMove)
      window.removeEventListener("touchend", onTouchEnd)
      window.removeEventListener("touchcancel", onTouchEnd)
    }
  }, [refreshing])

  if (pullDistance === 0 && !refreshing) return null

  const progress = Math.min(pullDistance / THRESHOLD, 1)

  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-x-0 z-[90] flex justify-center"
      style={{
        top: `calc(env(safe-area-inset-top) + ${Math.max(pullDistance - 40, 4)}px)`,
        transition: refreshing ? "top 200ms ease-out" : "none",
      }}
    >
      <div
        className="flex size-10 items-center justify-center rounded-full bg-background shadow-md ring-1 ring-border"
        style={{ opacity: Math.max(0.4, progress) }}
      >
        <RefreshCw
          className={cn("size-5 text-primary", refreshing && "animate-spin")}
          style={refreshing ? undefined : { transform: `rotate(${progress * 270}deg)` }}
        />
      </div>
    </div>
  )
}
