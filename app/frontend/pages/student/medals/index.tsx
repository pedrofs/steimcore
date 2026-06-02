import { Head } from "@inertiajs/react"
import { Lock } from "lucide-react"
import { motion, type Variants } from "motion/react"
import { useState } from "react"

import { BrandMonogram } from "@/components/brand"
import { Medal, metalForTierIndex } from "@/components/medal"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"

type Tier = { value: number; earned: boolean; earnedAt: string | null }

type Family = {
  key: string
  name: string
  color: string
  unit: string
  explanation: string
  locked: boolean
  currentValue: number | null
  bestValue: number | null
  highestTier: number | null
  tiers: Tier[]
}

type Props = { families: Family[] }

const section: Variants = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0 },
}

function formatDate(iso: string) {
  const date = new Date(iso)
  return new Intl.DateTimeFormat("pt-BR", { day: "numeric", month: "long", year: "numeric" }).format(
    date,
  )
}

// The medal shown for a family in the grid: the highest earned tier (full
// color), or the first threshold in grayscale when nothing's earned yet.
function gridTier(family: Family): { value: number; index: number; locked: boolean } {
  if (family.highestTier !== null) {
    const index = family.tiers.findIndex((t) => t.value === family.highestTier)
    return { value: family.highestTier, index: Math.max(index, 0), locked: false }
  }
  return { value: family.tiers[0]?.value ?? 1, index: 0, locked: true }
}

export default function StudentMedals({ families }: Props) {
  const [selected, setSelected] = useState<Family | null>(null)
  const earnedCount = families.filter((f) => !f.locked).length

  return (
    <>
      <Head title="Medalhas" />
      <div className="mx-auto w-full max-w-md">
        <Header earnedCount={earnedCount} />

        <motion.div
          className="grid grid-cols-2 gap-3 px-4 mt-4"
          initial="hidden"
          animate="show"
          transition={{ staggerChildren: 0.07, delayChildren: 0.1 }}
        >
          {families.map((family) => (
            <motion.div
              key={family.key}
              variants={section}
              transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
            >
              <FamilyCard family={family} onSelect={() => setSelected(family)} />
            </motion.div>
          ))}
        </motion.div>
      </div>

      <FamilySheet family={selected} onClose={() => setSelected(null)} />
    </>
  )
}

function Header({ earnedCount }: { earnedCount: number }) {
  return (
    <section className="relative overflow-hidden rounded-b-[2rem] bg-brand px-6 pb-12 pt-[calc(env(safe-area-inset-top)+1.75rem)] text-brand-foreground">
      <BrandMonogram
        title=""
        className="pointer-events-none absolute -top-10 -right-8 h-52 w-52 text-white/10"
      />
      <motion.p
        className="text-sm font-medium text-brand-foreground/85"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: "easeOut" }}
      >
        Suas conquistas
      </motion.p>
      <motion.h1
        className="mt-1.5 font-display text-[2.1rem] font-extrabold uppercase leading-[1.04] tracking-tight"
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.08, ease: [0.16, 1, 0.3, 1] }}
      >
        Medalhas
      </motion.h1>
      <motion.p
        className="mt-2 text-sm text-brand-foreground/85"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4, delay: 0.16 }}
      >
        {earnedCount > 0
          ? `${earnedCount} ${earnedCount === 1 ? "medalha conquistada" : "medalhas conquistadas"}`
          : "Comece a treinar para desbloquear"}
      </motion.p>
    </section>
  )
}

function FamilyCard({ family, onSelect }: { family: Family; onSelect: () => void }) {
  const tier = gridTier(family)
  const metal = metalForTierIndex(tier.index, family.tiers.length)

  return (
    <button
      type="button"
      onClick={onSelect}
      className="flex w-full flex-col items-center gap-3 rounded-2xl border bg-card p-5 text-center shadow-lg shadow-brand/5 transition-transform motion-safe:active:scale-[0.97]"
    >
      <Medal color={family.color} count={tier.value} metal={metal} locked={tier.locked} className="w-20" />
      <span className="mt-1 min-w-0">
        <span className="block font-heading text-sm font-semibold">{family.name}</span>
        <span className="mt-0.5 block text-xs text-muted-foreground">
          {family.locked ? "Bloqueada" : `Nível ${tier.value}`}
        </span>
      </span>
    </button>
  )
}

function FamilySheet({ family, onClose }: { family: Family | null; onClose: () => void }) {
  return (
    <Sheet open={family !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        side="bottom"
        className="max-h-[min(85vh,calc(100dvh-env(safe-area-inset-top)-1rem))] overflow-y-auto"
      >
        {family && <FamilyDetail family={family} />}
      </SheetContent>
    </Sheet>
  )
}

function FamilyDetail({ family }: { family: Family }) {
  return (
    <>
      <SheetHeader>
        <SheetTitle className="font-display text-2xl font-extrabold tracking-tight">
          {family.name}
        </SheetTitle>
        <SheetDescription>{family.explanation}</SheetDescription>
      </SheetHeader>

      <div className="flex flex-col gap-5 p-4 pt-0">
        <Stats family={family} />
        <TierLadder family={family} />
      </div>
    </>
  )
}

function Stats({ family }: { family: Family }) {
  if (family.currentValue === null) {
    return (
      <p className="rounded-xl border border-dashed bg-muted/40 p-4 text-sm text-muted-foreground">
        Disponível quando seu treinador definir sua meta semanal.
      </p>
    )
  }

  const best = family.bestValue ?? family.currentValue

  return (
    <div className="grid grid-cols-2 gap-3">
      <Stat label="Atual" value={family.currentValue} unit={family.unit} />
      <Stat label="Recorde" value={best} unit={family.unit} accent />
    </div>
  )
}

function Stat({
  label,
  value,
  unit,
  accent,
}: {
  label: string
  value: number
  unit: string
  accent?: boolean
}) {
  return (
    <div className="rounded-xl border bg-card p-4">
      <p className="text-[0.7rem] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
        {label}
      </p>
      <p className="mt-1.5 font-display text-2xl font-bold">
        <span className={accent ? "text-brand" : "text-foreground"}>{value}</span>{" "}
        <span className="text-sm font-medium text-muted-foreground">{unit}</span>
      </p>
    </div>
  )
}

function TierLadder({ family }: { family: Family }) {
  return (
    <div>
      <p className="mb-2 text-[0.7rem] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
        Níveis
      </p>
      <ul className="space-y-2">
        {family.tiers.map((tier, index) => {
          const metal = metalForTierIndex(index, family.tiers.length)
          return (
            <li
              key={tier.value}
              className={cn(
                "flex items-center gap-3 rounded-xl border p-3",
                tier.earned ? "border-border bg-card" : "border-dashed bg-muted/30",
              )}
            >
              <Medal
                color={family.color}
                count={tier.value}
                metal={metal}
                locked={!tier.earned}
                className="w-11 shrink-0"
              />
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-semibold">
                  {tier.value} {family.unit}
                </span>
                <span className="mt-0.5 block text-xs text-muted-foreground">
                  {tier.earned && tier.earnedAt
                    ? `Conquistada em ${formatDate(tier.earnedAt)}`
                    : "Ainda não conquistada"}
                </span>
              </span>
              {!tier.earned && <Lock className="size-4 shrink-0 text-muted-foreground/60" />}
            </li>
          )
        })}
      </ul>
    </div>
  )
}
