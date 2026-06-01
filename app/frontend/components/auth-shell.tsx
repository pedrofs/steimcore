import type { ReactNode } from "react"
import { Head, Link } from "@inertiajs/react"
import { motion } from "motion/react"

import { BrandLockup } from "@/components/brand"
import { cn } from "@/lib/utils"

type Props = {
  /** Document title (suffixed with the brand name by Inertia). */
  title?: string
  /** Heading rendered at the top of the card. */
  heading?: ReactNode
  /** Supporting copy under the heading. */
  subheading?: ReactNode
  /** Card body — typically the form. */
  children: ReactNode
  /** Optional row rendered under the card (e.g. cross-flow links). */
  footer?: ReactNode
  /** Constrain the card width. Defaults to the narrow sign-in width. */
  className?: string
}

// Shared chrome for the unauthenticated surfaces (landing + sign in). Provides a
// branded ambient backdrop, the animated brand lockup (linking home), and a
// raised card. Keeps the auth screens visually consistent and removes the
// duplicated layout that used to live in each page.
export function AuthShell({
  title,
  heading,
  subheading,
  children,
  footer,
  className,
}: Props) {
  return (
    <>
      {title && <Head title={title} />}
      <div className="relative flex min-h-dvh flex-col items-center justify-center gap-8 overflow-hidden bg-background px-4 pt-[max(1.5rem,env(safe-area-inset-top))] pb-[max(1.5rem,env(safe-area-inset-bottom))]">
        <AmbientBackdrop />

        <Link
          href="/"
          aria-label="Página inicial"
          className="rounded-md outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
        >
          <BrandLockup size="lg" showTagline animate />
        </Link>

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className={cn(
            "w-full max-w-sm rounded-2xl border bg-card/80 p-6 shadow-lg ring-1 ring-black/[0.02] backdrop-blur-sm sm:p-7",
            className
          )}
        >
          {(heading || subheading) && (
            <div className="mb-5 space-y-1 text-center">
              {heading && (
                <h1 className="text-xl font-semibold tracking-tight">
                  {heading}
                </h1>
              )}
              {subheading && (
                <p className="text-sm text-muted-foreground">{subheading}</p>
              )}
            </div>
          )}
          {children}
        </motion.div>

        {footer && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.4, delay: 0.5 }}
            className="text-center text-sm text-muted-foreground"
          >
            {footer}
          </motion.div>
        )}
      </div>
    </>
  )
}

function AmbientBackdrop() {
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
      {/* Brand-tinted glow behind the lockup. */}
      <div className="absolute top-[-12%] left-1/2 h-[60vh] w-[60vh] -translate-x-1/2 rounded-full bg-brand/15 blur-3xl" />
      {/* Soft vignette so the card lifts off the background. */}
      <div className="absolute inset-0 bg-[radial-gradient(120%_120%_at_50%_0%,transparent_40%,var(--muted)_100%)] opacity-60" />
    </div>
  )
}
