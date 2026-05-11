import { useEffect, useRef, useState } from "react"

import { TabsList, TabsTrigger } from "@/components/ui/tabs"
import { cn } from "@/lib/utils"

type WorkoutTabItem = { id: string; name: string }

export function WorkoutsTabsList({
  workouts,
  className,
}: {
  workouts: WorkoutTabItem[]
  className?: string
}) {
  const scrollerRef = useRef<HTMLDivElement>(null)
  const [hasLeftOverflow, setHasLeftOverflow] = useState(false)
  const [hasRightOverflow, setHasRightOverflow] = useState(false)

  useEffect(() => {
    const scroller = scrollerRef.current
    if (!scroller) return

    const update = () => {
      const maxScroll = scroller.scrollWidth - scroller.clientWidth
      setHasLeftOverflow(scroller.scrollLeft > 1)
      setHasRightOverflow(maxScroll - scroller.scrollLeft > 1)
    }

    update()
    scroller.addEventListener("scroll", update, { passive: true })
    const ro = new ResizeObserver(update)
    ro.observe(scroller)
    return () => {
      scroller.removeEventListener("scroll", update)
      ro.disconnect()
    }
  }, [workouts.length])

  return (
    <div className={cn("relative", className)}>
      <div
        ref={scrollerRef}
        className="overflow-x-auto overscroll-x-contain rounded-lg [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        <TabsList className="flex h-9 w-max min-w-full justify-start">
          {workouts.map((w) => (
            <TabsTrigger key={w.id} value={w.id} className="shrink-0 flex-none">
              {w.name}
            </TabsTrigger>
          ))}
        </TabsList>
      </div>
      <div
        aria-hidden
        className={cn(
          "pointer-events-none absolute inset-y-0 left-0 w-8 rounded-l-lg bg-linear-to-r from-background to-transparent transition-opacity duration-150",
          hasLeftOverflow ? "opacity-100" : "opacity-0",
        )}
      />
      <div
        aria-hidden
        className={cn(
          "pointer-events-none absolute inset-y-0 right-0 w-8 rounded-r-lg bg-linear-to-l from-background to-transparent transition-opacity duration-150",
          hasRightOverflow ? "opacity-100" : "opacity-0",
        )}
      />
    </div>
  )
}
