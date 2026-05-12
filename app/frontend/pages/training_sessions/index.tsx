import { Head, Link, router, usePage } from "@inertiajs/react"
import { PlusIcon, XIcon } from "lucide-react"
import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import ReactMarkdown from "react-markdown"

import { Button } from "@/components/ui/button"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"

type ExerciseBlock = {
  kind: "exercise"
  name: string
  prescription: string
  rest_s?: number
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
  text_md: string
}

type Block = ExerciseBlock | GroupBlock | FreeformBlock

type TrainingSessionRow = {
  id: string
  student: { id: string; name: string }
  workoutId: string | null
  workoutName: string
  workoutPosition: number
  blocks: Block[]
  completedBlockIndices: string[]
  finishedAt: string | null
  createdAt: string
  trainerId: number
  swapOptions: SwapOption[]
}

type PickerCandidate = {
  id: string
  name: string
}

type SwapOption = {
  id: string
  name: string
  position: number
}

type Props = {
  trainingSessions: TrainingSessionRow[]
  pickerCandidates: PickerCandidate[]
  scope: "trainer" | "org"
}

const AVATAR_PALETTE = [
  "bg-rose-500",
  "bg-amber-500",
  "bg-emerald-500",
  "bg-sky-500",
  "bg-violet-500",
  "bg-fuchsia-500",
  "bg-orange-500",
  "bg-teal-500",
]

function initials(name: string) {
  return name
    .split(/\s+/)
    .filter((s) => s.length > 0)
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase()
}

function paletteColorFor(index: number) {
  return AVATAR_PALETTE[index % AVATAR_PALETTE.length]
}

const TOGGLE_RELOAD = {
  only: ["trainingSessions"],
  preserveState: true,
  preserveScroll: true,
} as const

const PICKER_RELOAD = {
  only: ["trainingSessions", "pickerCandidates"],
  preserveState: true,
  preserveScroll: true,
} as const

export default function TrainingSessionsIndex({
  trainingSessions,
  pickerCandidates,
}: Props) {
  const [pickerOpen, setPickerOpen] = useState(false)
  const [swapOpen, setSwapOpen] = useState(false)
  const [focusedId, setFocusedId] = useState<string | null>(
    () => trainingSessions[0]?.id ?? null,
  )
  const prevIdsRef = useRef<string[]>(trainingSessions.map((s) => s.id))
  const [pendingToggles, setPendingToggles] = useState<Map<string, boolean>>(
    () => new Map(),
  )

  useEffect(() => {
    const currentIds = trainingSessions.map((s) => s.id)
    const prevIds = prevIdsRef.current

    if (currentIds.length === 0) {
      setFocusedId(null)
    } else {
      const added = currentIds.filter((id) => !prevIds.includes(id))
      if (added.length === 1) {
        setFocusedId(added[0])
      } else if (!focusedId || !currentIds.includes(focusedId)) {
        const prevIdx = focusedId ? prevIds.indexOf(focusedId) : -1
        const next =
          (prevIdx >= 0 && currentIds[prevIdx]) ||
          currentIds[currentIds.length - 1] ||
          currentIds[0]
        setFocusedId(next)
      }
    }

    prevIdsRef.current = currentIds
  }, [trainingSessions, focusedId])

  const focused = useMemo(
    () => trainingSessions.find((s) => s.id === focusedId) ?? null,
    [trainingSessions, focusedId],
  )

  const isEmpty = trainingSessions.length === 0

  const clearPending = useCallback((key: string) => {
    setPendingToggles((prev) => {
      if (!prev.has(key)) return prev
      const next = new Map(prev)
      next.delete(key)
      return next
    })
  }, [])

  const toggleBlock = useCallback(
    (session: TrainingSessionRow, blockIndex: number) => {
      const indexStr = String(blockIndex)
      const key = `${session.id}:${indexStr}`
      const serverDone = session.completedBlockIndices.includes(indexStr)
      const optimisticDone = pendingToggles.has(key)
        ? (pendingToggles.get(key) as boolean)
        : serverDone
      const nextDone = !optimisticDone

      setPendingToggles((prev) => {
        const next = new Map(prev)
        next.set(key, nextDone)
        return next
      })

      if (nextDone) {
        router.post(
          `/training_sessions/${session.id}/block_completions`,
          { block_index: indexStr },
          { ...TOGGLE_RELOAD, onFinish: () => clearPending(key) },
        )
      } else {
        router.delete(
          `/training_sessions/${session.id}/block_completions/${indexStr}`,
          { ...TOGGLE_RELOAD, onFinish: () => clearPending(key) },
        )
      }
    },
    [pendingToggles, clearPending],
  )

  const isBlockDone = useCallback(
    (session: TrainingSessionRow, blockIndex: number) => {
      const indexStr = String(blockIndex)
      const key = `${session.id}:${indexStr}`
      if (pendingToggles.has(key)) return pendingToggles.get(key) as boolean
      return session.completedBlockIndices.includes(indexStr)
    },
    [pendingToggles],
  )

  const doneCountFor = useCallback(
    (session: TrainingSessionRow) => {
      let count = 0
      for (let i = 0; i < session.blocks.length; i++) {
        if (isBlockDone(session, i)) count++
      }
      return count
    },
    [isBlockDone],
  )

  function addStudent(studentId: string) {
    setPickerOpen(false)
    router.post(
      "/training_sessions",
      { student_id: studentId },
      PICKER_RELOAD,
    )
  }

  function finishFocused() {
    if (!focused) return
    router.post(
      `/training_sessions/${focused.id}/completion`,
      {},
      PICKER_RELOAD,
    )
  }

  function swapFocusedTo(workoutId: string) {
    if (!focused) return
    setSwapOpen(false)
    router.post(
      `/training_sessions/${focused.id}/workout_swap`,
      { workout_id: workoutId },
      TOGGLE_RELOAD,
    )
  }

  return (
    <>
      <Head title="Sessões ao vivo" />
      <FlashToaster />
      <div className="relative flex min-h-screen flex-col bg-neutral-50">
        <Link
          href="/"
          aria-label="Fechar"
          className="absolute top-3 right-3 z-20 inline-flex size-9 items-center justify-center rounded-full bg-white/70 text-muted-foreground hover:bg-muted hover:text-foreground"
        >
          <XIcon className="size-5" />
        </Link>

        {isEmpty ? (
          <div className="flex flex-1 items-center justify-center px-6">
            <Button
              size="lg"
              className="gap-2"
              onClick={() => setPickerOpen(true)}
              disabled={pickerCandidates.length === 0}
            >
              <PlusIcon className="size-5" />
              Adicionar aluno
            </Button>
          </div>
        ) : (
          <>
            <AvatarStrip
              sessions={trainingSessions}
              focusedId={focusedId}
              onFocus={setFocusedId}
              onAdd={() => setPickerOpen(true)}
              doneCountFor={doneCountFor}
            />

            {focused && (
              <FocusedView
                session={focused}
                doneCount={doneCountFor(focused)}
                isBlockDone={(i) => isBlockDone(focused, i)}
                onToggleBlock={(i) => toggleBlock(focused, i)}
                onFinish={finishFocused}
                onSwap={() => setSwapOpen(true)}
              />
            )}
          </>
        )}

        <PickerSheet
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          candidates={pickerCandidates}
          onPick={addStudent}
        />

        {focused && (
          <SwapSheet
            open={swapOpen}
            onOpenChange={setSwapOpen}
            session={focused}
            progressIsEmpty={doneCountFor(focused) === 0}
            onSwap={swapFocusedTo}
          />
        )}
      </div>
    </>
  )
}

function AvatarStrip({
  sessions,
  focusedId,
  onFocus,
  onAdd,
  doneCountFor,
}: {
  sessions: TrainingSessionRow[]
  focusedId: string | null
  onFocus: (id: string) => void
  onAdd: () => void
  doneCountFor: (session: TrainingSessionRow) => number
}) {
  return (
    <div className="sticky top-0 z-10 border-b border-neutral-200 bg-white/95 backdrop-blur">
      <div className="flex gap-2 overflow-x-auto px-3 py-3 pr-12">
        {sessions.map((session, index) => {
          const isActive = session.id === focusedId
          const done = doneCountFor(session)
          const total = session.blocks.length
          const pct = total > 0 ? Math.round((done / total) * 100) : 0
          return (
            <button
              key={session.id}
              type="button"
              onClick={() => onFocus(session.id)}
              className={cn(
                "flex shrink-0 flex-col items-center gap-1 rounded-2xl border px-2 py-2 transition",
                isActive
                  ? "border-neutral-900 bg-neutral-900 text-white shadow"
                  : "border-neutral-200 bg-white text-neutral-700",
              )}
            >
              <ProgressRing pct={pct} active={isActive}>
                <div
                  className={cn(
                    "flex h-11 w-11 items-center justify-center rounded-full text-sm font-semibold text-white",
                    paletteColorFor(index),
                  )}
                >
                  {initials(session.student.name)}
                </div>
              </ProgressRing>
              <span className="text-[10px] leading-none">
                {session.student.name.split(/\s+/)[0]}
              </span>
              <span
                className={cn(
                  "text-[10px] leading-none",
                  isActive ? "text-white/80" : "text-neutral-500",
                )}
              >
                {done}/{total}
              </span>
            </button>
          )
        })}
        <button
          type="button"
          onClick={onAdd}
          aria-label="Adicionar aluno"
          className="flex shrink-0 flex-col items-center justify-center gap-1 rounded-2xl border border-dashed border-neutral-300 px-3 text-neutral-400 hover:border-neutral-500 hover:text-neutral-600"
        >
          <PlusIcon className="size-6" />
          <span className="text-[10px]">Add</span>
        </button>
      </div>
    </div>
  )
}

function ProgressRing({
  pct,
  active,
  children,
}: {
  pct: number
  active: boolean
  children: React.ReactNode
}) {
  const ringColor = active ? "rgb(16 185 129)" : "rgb(16 185 129)"
  const trackColor = active ? "rgba(255,255,255,0.18)" : "rgb(229 231 235)"
  const angle = Math.max(0, Math.min(360, Math.round((pct / 100) * 360)))
  return (
    <div
      className="flex h-14 w-14 items-center justify-center rounded-full p-[3px]"
      style={{
        background: `conic-gradient(${ringColor} ${angle}deg, ${trackColor} ${angle}deg)`,
      }}
    >
      {children}
    </div>
  )
}

function FocusedView({
  session,
  doneCount,
  isBlockDone,
  onToggleBlock,
  onFinish,
  onSwap,
}: {
  session: TrainingSessionRow
  doneCount: number
  isBlockDone: (index: number) => boolean
  onToggleBlock: (index: number) => void
  onFinish: () => void
  onSwap: () => void
}) {
  const total = session.blocks.length
  const pct = total > 0 ? Math.round((doneCount / total) * 100) : 0

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 pb-24">
      <div className="mb-4 flex items-start justify-between gap-3">
        <div className="flex flex-col">
          <h1 className="text-lg font-semibold text-neutral-900">
            {session.student.name}
          </h1>
          <p className="text-sm text-neutral-600">{session.workoutName}</p>
          <p className="text-xs text-neutral-500">
            {doneCount} de {total} blocos · {pct}%
          </p>
        </div>
        <div className="flex flex-col items-end gap-2">
          <Button
            type="button"
            variant={session.finishedAt ? "outline" : "default"}
            onClick={onFinish}
          >
            {session.finishedAt ? "Reabrir" : "Finalizar"}
          </Button>
          {!session.finishedAt && session.swapOptions.length > 0 && (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={onSwap}
              className="text-xs"
            >
              Trocar treino
            </Button>
          )}
        </div>
      </div>

      {total === 0 ? (
        <p className="rounded-2xl border border-dashed bg-white p-6 text-center text-sm text-neutral-500">
          Esse treino não tem blocos.
        </p>
      ) : (
        <div className="space-y-2">
          {session.blocks.map((block, index) => (
            <BlockCard
              key={index}
              block={block}
              done={isBlockDone(index)}
              onToggle={() => onToggleBlock(index)}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function BlockCard({
  block,
  done,
  onToggle,
}: {
  block: Block
  done: boolean
  onToggle: () => void
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-pressed={done}
      className={cn(
        "block w-full rounded-2xl border p-3 text-left transition active:scale-95",
        done
          ? "border-emerald-500 bg-emerald-500 text-white shadow-sm"
          : "border-neutral-200 bg-white text-neutral-900",
      )}
    >
      {block.kind === "exercise" && <ExerciseCard block={block} done={done} />}
      {block.kind === "group" && <GroupCard block={block} done={done} />}
      {block.kind === "freeform" && <FreeformCard block={block} done={done} />}
    </button>
  )
}

function ExerciseCard({ block, done }: { block: ExerciseBlock; done: boolean }) {
  const muted = done ? "text-white/85" : "text-neutral-700"
  const fine = done ? "text-white/70" : "text-neutral-500"
  return (
    <div className="flex flex-col gap-1">
      <div className="text-base font-medium">{block.name}</div>
      <div className={cn("text-sm", muted)}>{block.prescription}</div>
      {typeof block.rest_s === "number" && (
        <div className={cn("text-xs", fine)}>Descanso: {block.rest_s}s</div>
      )}
      {block.notes && <div className={cn("text-xs", fine)}>{block.notes}</div>}
    </div>
  )
}

function GroupCard({ block, done }: { block: GroupBlock; done: boolean }) {
  const label = block.label?.trim() || "Grupo"
  const muted = done ? "text-white/85" : "text-neutral-700"
  const fine = done ? "text-white/70" : "text-neutral-500"
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between gap-2">
        <div className="text-base font-medium">{label}</div>
        {typeof block.rounds === "number" && (
          <div className={cn("text-xs font-medium", fine)}>
            {block.rounds} rounds
          </div>
        )}
      </div>
      <ul className="flex flex-col gap-1 pl-3">
        {block.items.map((item, idx) => (
          <li key={idx} className={cn("text-sm", muted)}>
            <span className="font-medium">{item.name}</span>
            <span className={cn(fine)}> · {item.prescription}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

const FREEFORM_COMPONENTS = {
  a: ({ children }: { children?: React.ReactNode }) => <span>{children}</span>,
  h1: ({ children }: { children?: React.ReactNode }) => (
    <p className="font-semibold">{children}</p>
  ),
  h2: ({ children }: { children?: React.ReactNode }) => (
    <p className="font-semibold">{children}</p>
  ),
  h3: ({ children }: { children?: React.ReactNode }) => (
    <p className="font-medium">{children}</p>
  ),
}

function FreeformCard({ block, done }: { block: FreeformBlock; done: boolean }) {
  return (
    <div
      className={cn(
        "prose prose-sm max-w-none text-sm leading-relaxed",
        done ? "prose-invert" : "prose-neutral",
      )}
    >
      <ReactMarkdown skipHtml components={FREEFORM_COMPONENTS}>
        {block.text_md}
      </ReactMarkdown>
    </div>
  )
}

function PickerSheet({
  open,
  onOpenChange,
  candidates,
  onPick,
}: {
  open: boolean
  onOpenChange: (next: boolean) => void
  candidates: PickerCandidate[]
  onPick: (id: string) => void
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="max-h-[80vh] overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Adicionar aluno</SheetTitle>
        </SheetHeader>
        <div className="flex flex-col gap-1 p-4 pt-0">
          {candidates.length === 0 ? (
            <p className="rounded-xl border border-dashed bg-muted/20 p-6 text-center text-sm text-muted-foreground">
              Nenhum aluno elegível no momento.
            </p>
          ) : (
            candidates.map((candidate) => (
              <button
                key={candidate.id}
                type="button"
                onClick={() => onPick(candidate.id)}
                className="flex h-12 items-center justify-between rounded-xl border border-transparent bg-white px-3 text-left text-sm font-medium text-neutral-900 transition hover:bg-muted active:scale-[0.98]"
              >
                {candidate.name}
              </button>
            ))
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}

function SwapSheet({
  open,
  onOpenChange,
  session,
  progressIsEmpty,
  onSwap,
}: {
  open: boolean
  onOpenChange: (next: boolean) => void
  session: TrainingSessionRow
  progressIsEmpty: boolean
  onSwap: (workoutId: string) => void
}) {
  const [pendingWorkoutId, setPendingWorkoutId] = useState<string | null>(null)

  useEffect(() => {
    if (!open) setPendingWorkoutId(null)
  }, [open])

  const pendingWorkout = pendingWorkoutId
    ? session.swapOptions.find((w) => w.id === pendingWorkoutId)
    : null

  function handlePick(workoutId: string) {
    if (workoutId === session.workoutId) return
    if (progressIsEmpty) {
      onSwap(workoutId)
    } else {
      setPendingWorkoutId(workoutId)
    }
  }

  function confirm() {
    if (pendingWorkoutId) onSwap(pendingWorkoutId)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="max-h-[80vh] overflow-y-auto">
        <SheetHeader>
          <SheetTitle>
            {pendingWorkout ? "Confirmar troca" : "Trocar treino"}
          </SheetTitle>
        </SheetHeader>
        {pendingWorkout ? (
          <div className="flex flex-col gap-4 p-4 pt-0">
            <p className="text-sm text-neutral-700">
              O progresso atual será perdido. Continuar?
            </p>
            <p className="text-xs text-neutral-500">
              Novo treino: <span className="font-medium">{pendingWorkout.name}</span>
            </p>
            <div className="flex gap-2">
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => setPendingWorkoutId(null)}
              >
                Cancelar
              </Button>
              <Button type="button" className="flex-1" onClick={confirm}>
                Confirmar
              </Button>
            </div>
          </div>
        ) : (
          <div className="flex flex-col gap-1 p-4 pt-0">
            {session.swapOptions.length === 0 ? (
              <p className="rounded-xl border border-dashed bg-muted/20 p-6 text-center text-sm text-muted-foreground">
                Nenhum treino disponível para troca.
              </p>
            ) : (
              session.swapOptions.map((option) => {
                const isCurrent = option.id === session.workoutId
                return (
                  <button
                    key={option.id}
                    type="button"
                    onClick={() => handlePick(option.id)}
                    disabled={isCurrent}
                    className={cn(
                      "flex h-12 items-center justify-between rounded-xl border border-transparent px-3 text-left text-sm font-medium transition",
                      isCurrent
                        ? "bg-muted/40 text-muted-foreground"
                        : "bg-white text-neutral-900 hover:bg-muted active:scale-[0.98]",
                    )}
                  >
                    <span>{option.name}</span>
                    {isCurrent && (
                      <span className="text-xs text-muted-foreground">Atual</span>
                    )}
                  </button>
                )
              })
            )}
          </div>
        )}
      </SheetContent>
    </Sheet>
  )
}

function FlashToaster() {
  const { flash } = usePage().props
  const alert = flash.alert
  const [visible, setVisible] = useState<string | null>(null)

  useEffect(() => {
    if (!alert) return
    setVisible(alert)
    const id = window.setTimeout(() => setVisible(null), 4000)
    return () => window.clearTimeout(id)
  }, [alert])

  if (!visible) return null
  return (
    <div
      role="status"
      className="fixed inset-x-0 bottom-6 z-30 mx-auto w-fit max-w-[90%] rounded-full bg-neutral-900 px-4 py-2 text-sm font-medium text-white shadow-lg"
    >
      {visible}
    </div>
  )
}
