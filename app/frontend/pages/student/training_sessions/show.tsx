import { Head, Link } from "@inertiajs/react"
import { ChevronLeft, DumbbellIcon } from "lucide-react"
import { motion } from "motion/react"

import { BrandMonogram } from "@/components/brand"
import { cn } from "@/lib/utils"

type ExerciseBlock = {
  kind: "exercise"
  name: string
  prescription: string
  restS?: number
  notes?: string
}

type GroupItem = {
  name: string
  prescription: string
  notes?: string
}

type GroupBlock = {
  kind: "group"
  label?: string
  rounds?: number
  items: GroupItem[]
}

type FreeformBlock = {
  kind: "freeform"
  textMd: string
}

type Block = ExerciseBlock | GroupBlock | FreeformBlock

type LiveSession = {
  id: string
  workoutName: string
  workoutPosition: number
  blocks: Block[]
  completedBlockIndices: string[]
  finishedAt: string | null
  initiator: "student" | "trainer"
}

type Props = {
  session: LiveSession
}

export default function StudentLiveSession({ session }: Props) {
  return (
    <div className="min-h-dvh bg-background">
      <Head title={session.workoutName} />

      <header className="relative overflow-hidden rounded-b-[2rem] bg-brand px-5 pb-7 pt-[calc(env(safe-area-inset-top)+0.75rem)] text-brand-foreground">
        <BrandMonogram
          title=""
          className="pointer-events-none absolute -top-8 -right-6 h-44 w-44 text-white/10"
        />

        <Link
          href="/student/home"
          className="inline-flex items-center gap-1 text-sm font-medium text-brand-foreground/85 transition-colors hover:text-brand-foreground"
        >
          <ChevronLeft className="size-4" />
          Início
        </Link>

        <p className="mt-5 text-[0.7rem] font-semibold uppercase tracking-[0.16em] text-brand-foreground/80">
          {session.initiator === "trainer" ? "Sessão com seu treinador" : "Treino em andamento"}
        </p>
        <h1 className="mt-1 flex items-center gap-2 font-display text-[2rem] font-extrabold uppercase leading-[1.05] tracking-tight">
          <DumbbellIcon className="size-6 shrink-0" />
          {session.workoutName}
        </h1>
      </header>

      <motion.ol
        className="mx-auto w-full max-w-md space-y-3 px-4 pb-[calc(env(safe-area-inset-bottom)+2rem)] pt-5"
        initial="hidden"
        animate="show"
        transition={{ staggerChildren: 0.06, delayChildren: 0.05 }}
      >
        {session.blocks.map((block, index) => (
          <motion.li
            key={index}
            variants={{ hidden: { opacity: 0, y: 12 }, show: { opacity: 1, y: 0 } }}
            transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
          >
            <BlockCard block={block} index={index} />
          </motion.li>
        ))}

        {session.blocks.length === 0 && (
          <li className="rounded-2xl border border-dashed p-6 text-center text-sm text-muted-foreground">
            Este treino não tem blocos cadastrados.
          </li>
        )}
      </motion.ol>
    </div>
  )
}

function BlockCard({ block, index }: { block: Block; index: number }) {
  return (
    <div className="rounded-2xl border bg-card p-4 shadow-sm shadow-brand/5">
      <div className="flex items-baseline gap-2.5">
        <span className="font-display text-sm font-bold tabular-nums text-brand">
          {String(index + 1).padStart(2, "0")}
        </span>
        <div className="min-w-0 flex-1">
          {block.kind === "exercise" && <ExerciseBody block={block} />}
          {block.kind === "group" && <GroupBody block={block} />}
          {block.kind === "freeform" && <FreeformBody block={block} />}
        </div>
      </div>
    </div>
  )
}

function ExerciseBody({ block }: { block: ExerciseBlock }) {
  return (
    <div className="flex items-baseline justify-between gap-3">
      <span className="truncate font-heading text-sm font-semibold">{block.name}</span>
      <span className="shrink-0 text-sm tabular-nums text-muted-foreground">
        {block.prescription}
      </span>
    </div>
  )
}

function GroupBody({ block }: { block: GroupBlock }) {
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3">
        <span className="font-heading text-sm font-semibold">{block.label ?? "Circuito"}</span>
        {block.rounds != null && (
          <span className="shrink-0 text-xs font-medium uppercase tracking-wide text-brand">
            {block.rounds}x
          </span>
        )}
      </div>
      <ul className="mt-2 space-y-1.5 border-l-2 border-brand/15 pl-3">
        {block.items.map((item, i) => (
          <li key={i} className="flex items-baseline justify-between gap-3">
            <span className="truncate text-sm font-medium">{item.name}</span>
            <span className="shrink-0 text-sm tabular-nums text-muted-foreground">
              {item.prescription}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}

function FreeformBody({ block }: { block: FreeformBlock }) {
  return (
    <p className={cn("whitespace-pre-line text-sm text-muted-foreground")}>{block.textMd}</p>
  )
}
