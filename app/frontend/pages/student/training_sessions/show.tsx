import { Head, Link, router } from "@inertiajs/react"
import { CheckIcon, ChevronLeft, DumbbellIcon } from "lucide-react"
import { motion } from "motion/react"
import { useCallback, useState } from "react"

import { BrandMonogram } from "@/components/brand"
import { ExerciseMedia } from "@/components/exercise-media"
import { Button } from "@/components/ui/button"
import { WeightControl } from "@/components/weight-control"
import type {
  Block,
  ExerciseBlock,
  FreeformBlock,
  GroupBlock,
} from "@/lib/blocks"
import { cn } from "@/lib/utils"

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

const TOGGLE_RELOAD = { preserveScroll: true, only: ["session"] }

export default function StudentLiveSession({ session }: Props) {
  const finished = session.finishedAt != null
  const [pendingToggles, setPendingToggles] = useState<Map<string, boolean>>(
    new Map(),
  )

  const isBlockDone = useCallback(
    (index: number) => {
      const indexStr = String(index)
      if (pendingToggles.has(indexStr)) return pendingToggles.get(indexStr) as boolean
      return session.completedBlockIndices.includes(indexStr)
    },
    [pendingToggles, session.completedBlockIndices],
  )

  const toggleBlock = useCallback(
    (index: number) => {
      if (finished) return
      const indexStr = String(index)
      const nextDone = !isBlockDone(index)

      setPendingToggles((prev) => new Map(prev).set(indexStr, nextDone))

      const clear = () =>
        setPendingToggles((prev) => {
          const next = new Map(prev)
          next.delete(indexStr)
          return next
        })

      if (nextDone) {
        router.post(
          `/student/training_sessions/${session.id}/block_completions`,
          { block_index: indexStr },
          { onSuccess: clear, ...TOGGLE_RELOAD },
        )
      } else {
        router.delete(
          `/student/training_sessions/${session.id}/block_completions/${indexStr}`,
          { onSuccess: clear, ...TOGGLE_RELOAD },
        )
      }
    },
    [finished, isBlockDone, session.id],
  )

  const setLoad = useCallback(
    (exerciseName: string, value: string) => {
      router.post(
        `/student/training_sessions/${session.id}/exercise_loads`,
        { exerciseName, value },
        { preserveScroll: true, only: ["session"] },
      )
    },
    [session.id],
  )

  function finish() {
    router.post(`/student/training_sessions/${session.id}/completion`, {})
  }

  function cancel() {
    if (!window.confirm("Cancelar este treino? Nada será registrado.")) return
    router.delete(`/student/training_sessions/${session.id}`)
  }

  const doneCount = session.blocks.reduce(
    (count, _block, index) => (isBlockDone(index) ? count + 1 : count),
    0,
  )
  const allDone = session.blocks.length > 0 && doneCount === session.blocks.length

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

        {session.blocks.length > 0 && (
          <p className="mt-3 text-sm font-medium tabular-nums text-brand-foreground/85">
            {doneCount} de {session.blocks.length} blocos concluídos
          </p>
        )}
      </header>

      <motion.ol
        className="mx-auto w-full max-w-md space-y-3 px-4 pb-[calc(env(safe-area-inset-bottom)+7rem)] pt-5"
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
            <BlockCard
              block={block}
              done={isBlockDone(index)}
              disabled={finished}
              onToggle={() => toggleBlock(index)}
              onSetLoad={setLoad}
            />
          </motion.li>
        ))}

        {session.blocks.length === 0 && (
          <li className="rounded-2xl border border-dashed p-6 text-center text-sm text-muted-foreground">
            Este treino não tem blocos cadastrados.
          </li>
        )}
      </motion.ol>

      {!finished && (
        <div className="fixed inset-x-0 bottom-0 border-t bg-background/95 px-4 pb-[calc(env(safe-area-inset-bottom)+1rem)] pt-3 backdrop-blur">
          <div className="mx-auto flex w-full max-w-md flex-col items-center gap-2">
            <Button
              onClick={finish}
              size="lg"
              className="flex w-full"
              variant={allDone ? "default" : "outline"}
            >
              Concluir treino
            </Button>

            {session.initiator === "student" && (
              <button
                type="button"
                onClick={cancel}
                className="text-sm font-medium text-muted-foreground transition-colors hover:text-destructive"
              >
                Cancelar treino
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function BlockCard({
  block,
  done,
  disabled,
  onToggle,
  onSetLoad,
}: {
  block: Block
  done: boolean
  disabled: boolean
  onToggle: () => void
  onSetLoad: (exerciseName: string, value: string) => void
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      disabled={disabled}
      aria-pressed={done}
      className={cn(
        "flex w-full items-stretch gap-3 rounded-2xl border bg-card p-4 text-left shadow-sm shadow-brand/5 transition-colors",
        done && "border-brand/40 bg-brand/5",
        disabled && "cursor-default",
        !disabled && "active:bg-muted/50",
      )}
    >
      {done && (
        <span className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-brand text-brand-foreground">
          <CheckIcon className="size-4" />
        </span>
      )}

      <div className={cn("flex min-w-0 flex-1 flex-col justify-center", done && "opacity-60")}>
        {block.kind === "exercise" && <ExerciseBody block={block} />}
        {block.kind === "group" && (
          <GroupBody block={block} disabled={disabled} onSetLoad={onSetLoad} />
        )}
        {block.kind === "freeform" && <FreeformBody block={block} />}
      </div>

      {block.kind === "exercise" && (
        <WeightControl
          variant="cell"
          exerciseName={block.name}
          weight={block.weight}
          disabled={disabled}
          onSubmit={(value) => onSetLoad(block.name, value)}
        />
      )}
    </button>
  )
}

function ExerciseBody({ block }: { block: ExerciseBlock }) {
  return (
    <div className="flex items-center gap-2.5">
      <ExerciseMedia name={block.name} media={block.media} />
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="line-clamp-2 font-heading text-sm font-semibold leading-snug">
          {block.name}
        </span>
        <span className="text-sm tabular-nums text-muted-foreground">
          {block.prescription}
        </span>
      </div>
    </div>
  )
}

function GroupBody({
  block,
  disabled,
  onSetLoad,
}: {
  block: GroupBlock
  disabled: boolean
  onSetLoad: (exerciseName: string, value: string) => void
}) {
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
          <li key={i} className="flex items-stretch gap-2">
            <ExerciseMedia
              name={item.name}
              media={item.media}
              className="size-9 self-center"
            />
            <div className="flex min-w-0 flex-1 flex-col justify-center gap-0.5 self-center">
              <span className="line-clamp-2 text-sm font-medium leading-snug">{item.name}</span>
              <span className="text-sm tabular-nums text-muted-foreground">
                {item.prescription}
              </span>
            </div>
            <WeightControl
              variant="cell"
              exerciseName={item.name}
              weight={item.weight}
              disabled={disabled}
              onSubmit={(value) => onSetLoad(item.name, value)}
            />
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
