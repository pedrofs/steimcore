import { BrandMonogram } from "@/components/brand"
import { cn } from "@/lib/utils"

export type Metal = "bronze" | "silver" | "gold" | "platinum"

// The tier metal climbs bronze → silver → gold → platinum across a family's
// ladder. Bucket a tier by its position so longer ladders still span all four
// metals (e.g. the 8-tier workouts family lands its top tiers on platinum).
export function metalForTierIndex(index: number, total: number): Metal {
  const fraction = total <= 1 ? 1 : index / (total - 1)
  if (fraction < 0.25) return "bronze"
  if (fraction < 0.5) return "silver"
  if (fraction < 0.75) return "gold"
  return "platinum"
}

const METALS: Record<Metal, { rim: string; ring: string; sheen: string }> = {
  bronze: { rim: "#8a4f1d", ring: "#c2772f", sheen: "#e8a766" },
  silver: { rim: "#6b7280", ring: "#9aa3af", sheen: "#dde2e9" },
  gold: { rim: "#a87f1c", ring: "#e3b341", sheen: "#f7dd8c" },
  platinum: { rim: "#8d99a8", ring: "#cdd6e2", sheen: "#f2f6fb" },
}

// One branded achievement medal: the STEIMFIT "S" on the family color, framed
// by a tier metal ring, with a corner "×N" pill. `locked` desaturates the whole
// medallion for families/tiers the student hasn't earned yet.
export function Medal({
  color,
  count,
  metal,
  locked = false,
  className,
}: {
  color: string
  count: number
  metal: Metal
  locked?: boolean
  className?: string
}) {
  const m = METALS[metal]
  const gradientId = `medal-sheen-${metal}`

  return (
    <div className={cn("relative aspect-square", locked && "opacity-70 grayscale", className)}>
      <svg
        viewBox="0 0 100 100"
        className="size-full drop-shadow-sm"
        role="img"
        aria-hidden="true"
      >
        <defs>
          <radialGradient id={gradientId} cx="38%" cy="32%" r="75%">
            <stop offset="0%" stopColor={m.sheen} />
            <stop offset="55%" stopColor={m.ring} />
            <stop offset="100%" stopColor={m.rim} />
          </radialGradient>
        </defs>

        {/* Metal ring */}
        <circle cx="50" cy="50" r="49" fill={`url(#${gradientId})`} />
        <circle cx="50" cy="50" r="49" fill="none" stroke={m.rim} strokeWidth="1.5" />

        {/* Family-color disc */}
        <circle cx="50" cy="50" r="36" fill={color} />
        <circle cx="50" cy="50" r="36" fill="none" stroke="#00000022" strokeWidth="1" />
      </svg>

      {/* Centered monogram, tinted white over the family color */}
      <BrandMonogram
        title=""
        className="absolute inset-0 m-auto h-[34%] w-[34%] text-white"
      />

      {/* Corner ×N pill */}
      <span
        className={cn(
          "absolute -bottom-1 left-1/2 -translate-x-1/2 rounded-full border px-2 py-0.5",
          "text-[0.7rem] font-bold leading-none tabular-nums shadow-sm",
          locked
            ? "border-border bg-muted text-muted-foreground"
            : "border-white/70 bg-foreground text-background"
        )}
      >
        ×{count}
      </span>
    </div>
  )
}
