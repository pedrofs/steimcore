import { PlayIcon } from "lucide-react"

import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from "@/components/ui/drawer"
import { cn } from "@/lib/utils"

export type ExerciseMediaItem = {
  id: string
  thumbUrl: string
  fullUrl: string
  isVideo: boolean
}

// Inline thumbnail for a linked, Enriched exercise that opens a Drawer with all
// of its media — videos play, images show full-size. Resolved live at read time
// by BlockMedia (server side), so it renders nothing when the exercise carries
// no ready media. The trigger is a span (not a button) and stops click
// propagation so tapping it never toggles the surrounding block card.
export function ExerciseMedia({
  name,
  media,
  className,
}: {
  name: string
  media?: ExerciseMediaItem[] | null
  className?: string
}) {
  if (!media || media.length === 0) return null

  const primary = media[0]

  return (
    <Drawer>
      <DrawerTrigger asChild>
        <span
          role="button"
          tabIndex={0}
          aria-label={`Ver mídia de ${name}`}
          onClick={(event) => event.stopPropagation()}
          className={cn(
            "relative block size-11 shrink-0 cursor-pointer overflow-hidden rounded-lg border bg-muted",
            className,
          )}
        >
          <img
            src={primary.thumbUrl}
            alt=""
            loading="lazy"
            className="size-full object-cover"
          />
          {primary.isVideo && (
            <span className="absolute inset-0 flex items-center justify-center bg-black/25">
              <PlayIcon className="size-4 fill-white text-white" />
            </span>
          )}
        </span>
      </DrawerTrigger>

      <DrawerContent onClick={(event) => event.stopPropagation()}>
        <DrawerHeader>
          <DrawerTitle>{name}</DrawerTitle>
        </DrawerHeader>
        <div className="flex flex-col gap-4 overflow-y-auto px-4 pb-[calc(env(safe-area-inset-bottom)+1.5rem)]">
          {media.map((item) =>
            item.isVideo ? (
              <video
                key={item.id}
                src={item.fullUrl}
                poster={item.thumbUrl}
                controls
                playsInline
                preload="none"
                className="w-full rounded-lg bg-black"
              />
            ) : (
              <img
                key={item.id}
                src={item.fullUrl}
                alt={name}
                className="w-full rounded-lg"
              />
            ),
          )}
        </div>
      </DrawerContent>
    </Drawer>
  )
}
