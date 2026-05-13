import { cn } from "@/lib/utils"
import { BRAND_NAME, BRAND_TAGLINE } from "@/lib/brand"

type Tone = "color" | "black" | "white"

type ToneColors = { hex: string; monogram: string; wordmark: string }

const tones: Record<Tone, ToneColors> = {
  color: {
    hex: "#a80038",
    monogram: "#fbf9fa",
    wordmark: "currentColor",
  },
  black: {
    hex: "#0a0a0a",
    monogram: "#fbf9fa",
    wordmark: "currentColor",
  },
  white: {
    hex: "#fbf9fa",
    monogram: "#a80038",
    wordmark: "currentColor",
  },
}

export function BrandMark({
  tone = "color",
  className,
  title = BRAND_NAME,
}: {
  tone?: Tone
  className?: string
  title?: string
}) {
  const { hex, monogram } = tones[tone]
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="100 170 1330 1330"
      role="img"
      aria-label={title}
      className={cn("shrink-0", className)}
    >
      <g transform="scale(8.174386920980927) translate(10, 10)">
        <g
          transform="matrix(2.5560852997962904,0,0,2.5560852997962904,20.000018807798714,20.01066793863929)"
          fill={hex}
        >
          <path d="M23.11 55.78L1.69 43.41A3.39 3.39 0 0 1 0 40.48V15.75a3.39 3.39 0 0 1 1.69-2.94L23.11.45a3.39 3.39 0 0 1 3.39 0l21.41 12.37a3.39 3.39 0 0 1 1.69 2.94v24.72a3.39 3.39 0 0 1-1.69 2.94L26.5 55.78a3.39 3.39 0 0 1-3.39 0z" />
        </g>
        <g
          transform="matrix(2.123692236962225,0,0,2.123692236962225,51.741162863989025,10.893202832917865)"
          fill={monogram}
        >
          <path d="M8.8932 46.475 c-0.34383 0 -0.6864 -0.10383 -1.0517 -0.315 l-5.2511 -3.0354 c-0.7302 -0.4224 -1.0518 -0.9798 -1.0518 -1.8234 l0 -19.54 c0 -0.8436 0.32162 -1.401 1.0518 -1.8234 l5.5158 -3.1884 c0.23039 -0.13858 0.49981 -0.21838 0.7878 -0.21838 c0.8448 0 1.53 0.6852 1.53 1.53 c0 0.57598 -0.31858 1.0776 -0.78894 1.3386 l-5.037 2.9112 l0 18.439 l4.296 2.4828 l10.864 -6.2796 c0.23039 -0.13858 0.49981 -0.21838 0.7878 -0.21838 c0.8448 0 1.53 0.6852 1.53 1.53 c0 0.57598 -0.31858 1.0776 -0.78894 1.3386 l-11.34 6.555 c-0.36539 0.21117 -0.7092 0.31676 -1.0531 0.31676 z M8.8944 59.947148 l0.0032227 0.00058594 c-0.34383 0 -0.68766 -0.10559 -1.0531 -0.31676 l-5.2511 -3.0354 c-0.7302 -0.4224 -1.0506 -0.9798 -1.0517 -1.8234 l-0.0072072 -6.4086 c0 -0.8256 0.6858 -1.5222 1.5288 -1.5222 c0.25981 0 0.5226 0.065976 0.76374 0.20519 l5.0676 2.9238 l5.0382 -2.9124 c0.23039 -0.13858 0.49981 -0.21838 0.7878 -0.21838 c0.8448 0 1.53 0.6852 1.53 1.53 c0 0.57598 -0.31858 1.0776 -0.78894 1.3386 l-5.514 3.1872 c-0.36539 0.21117 -0.7092 0.31676 -1.0531 0.31676 s-0.68766 -0.10559 -1.0531 -0.31676 l-3.243 -1.8744 l0 3.2004 l4.296 2.4834 l10.121 -5.8506 l0 -5.8524 c0 -0.8448 0.6852 -1.53 1.53 -1.53 s1.53 0.6852 1.53 1.53 l0 6.4026 c0 0.8436 -0.32162 1.401 -1.0518 1.8174 l-11.077 6.4086 c-0.36539 0.21117 -0.7092 0.31676 -1.0531 0.31676 z M20.549 60.0023438 c-0.8448 0 -1.5325 -0.68694 -1.5325 -1.5317 c0 -0.57598 0.31858 -1.0776 0.78894 -1.3386 l5.037 -2.9112 l0 -18.439 l-4.296 -2.4828 l-5.0382 2.9118 c-0.22981 0.13858 -0.49922 0.21838 -0.7872 0.21838 c-0.8448 0 -1.53 -0.6852 -1.53 -1.53 c0 -0.57598 0.31858 -1.0776 0.78894 -1.3386 l5.514 -3.1872 c0.36539 -0.21117 0.7092 -0.31676 1.0531 -0.31676 s0.68766 0.10559 1.0531 0.31676 l5.2511 3.0354 c0.7308 0.4224 1.0524 0.9798 1.0524 1.8234 l0 19.54 c0 0.8436 -0.32162 1.401 -1.0518 1.8234 l-5.5158 3.1884 c-0.22981 0.13858 -0.49922 0.21838 -0.7872 0.21838 z M8.895 39.796 c-0.8448 0 -1.532 -0.68586 -1.532 -1.5307 l0 -6.4026 c0 -0.8436 0.32162 -1.401 1.0518 -1.8234 l11.077 -6.4026 c0.36539 -0.21117 0.7092 -0.31676 1.0531 -0.31676 s0.68766 0.10559 1.0531 0.31676 l3.243 1.8744 l0 -3.2004 l-4.296 -2.4834 l-10.864 6.2796 c-0.23039 0.13858 -0.49981 0.21838 -0.7878 0.21838 c-0.8448 0 -1.53 -0.6852 -1.53 -1.53 c0 -0.57598 0.31858 -1.0776 0.78894 -1.3386 l11.34 -6.555 c0.36539 -0.21117 0.7092 -0.31676 1.0531 -0.31676 s0.68766 0.10559 1.0531 0.31676 l5.2511 3.0354 c0.7308 0.4224 1.0524 0.9798 1.0524 1.8234 l0 6.9372 c0 0.8532 -0.37981 1.3289 -0.9696 1.3289 c-0.25318 0 -0.54539 -0.0876 -0.8628 -0.27117 l-5.523 -3.1926 l-10.121 5.8506 l0 5.8524 c0 0.8448 -0.6852 1.53 -1.53 1.53 z" />
        </g>
      </g>
    </svg>
  )
}

type LockupSize = "sm" | "md" | "lg"

const lockupSizes: Record<
  LockupSize,
  { mark: string; wordmark: string; tagline: string; gap: string }
> = {
  sm: { mark: "size-7", wordmark: "text-lg", tagline: "text-[9px]", gap: "gap-2" },
  md: { mark: "size-10", wordmark: "text-2xl", tagline: "text-[11px]", gap: "gap-2.5" },
  lg: { mark: "size-16", wordmark: "text-4xl", tagline: "text-xs", gap: "gap-3" },
}

export function BrandLockup({
  tone = "color",
  size = "md",
  showTagline = false,
  animate = false,
  className,
}: {
  tone?: Tone
  size?: LockupSize
  showTagline?: boolean
  animate?: boolean
  className?: string
}) {
  const s = lockupSizes[size]
  return (
    <div className={cn("inline-flex items-center", s.gap, className)}>
      <BrandMark
        tone={tone}
        className={cn(
          s.mark,
          animate &&
            "motion-safe:animate-in motion-safe:zoom-in-90 motion-safe:fade-in-0 motion-safe:duration-500 motion-safe:fill-mode-both motion-safe:ease-out",
        )}
        title={`${BRAND_NAME} mark`}
      />
      <div className="flex flex-col leading-none">
        <span
          className={cn(
            "font-display font-extrabold uppercase tracking-tight",
            s.wordmark,
            animate &&
              "motion-safe:animate-in motion-safe:slide-in-from-left-2 motion-safe:fade-in-0 motion-safe:duration-400 motion-safe:delay-200 motion-safe:fill-mode-both motion-safe:ease-out",
          )}
        >
          {BRAND_NAME}
        </span>
        {showTagline && (
          <span
            className={cn(
              "mt-1 font-medium uppercase tracking-[0.18em] text-muted-foreground",
              s.tagline,
              animate &&
                "motion-safe:animate-in motion-safe:fade-in-0 motion-safe:duration-300 motion-safe:delay-400 motion-safe:fill-mode-both",
            )}
          >
            {BRAND_TAGLINE}
          </span>
        )}
      </div>
    </div>
  )
}
