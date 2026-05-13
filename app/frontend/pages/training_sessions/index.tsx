import { Head, Link, router, usePage } from "@inertiajs/react"
import { ClockIcon, PlusIcon, XIcon } from "lucide-react"
import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import ReactMarkdown from "react-markdown"

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"

import { initials, paletteColorFor } from "./avatar"

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
  textMd: string
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
  stale: boolean
  trainerId: number
  trainerName: string
  swapOptions: SwapOption[]
}

type IneligibleReason = "no_periodization" | "generating" | "already_active"

const INELIGIBLE_REASON_LABELS: Record<IneligibleReason, string> = {
  no_periodization: "Sem treino ativo",
  generating: "Treino sendo gerado",
  already_active: "Em sessão ativa",
}

type PickerCandidate = {
  id: string
  name: string
  eligible: boolean
  ineligibleReason: IneligibleReason | null
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

type Scope = "trainer" | "org"

const TOGGLE_RELOAD = {
  only: ["trainingSessions"],
  preserveState: true,
  preserveScroll: true,
}

const PICKER_RELOAD = {
  only: ["trainingSessions", "pickerCandidates"],
  preserveState: true,
  preserveScroll: true,
}

export default function TrainingSessionsIndex({
  trainingSessions,
  pickerCandidates,
  scope,
}: Props) {
  const currentUserId = usePage().props.currentUser?.id ?? null
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
          { onSuccess: () => clearPending(key), ...TOGGLE_RELOAD },
        )
      } else {
        router.delete(
          `/training_sessions/${session.id}/block_completions/${indexStr}`,
          { onSuccess: () => clearPending(key), ...TOGGLE_RELOAD },
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
      <div className="relative flex min-h-screen flex-col bg-muted/30">
        <Link
          href="/"
          aria-label="Fechar"
          className="absolute top-3 right-3 z-20 inline-flex size-9 items-center justify-center rounded-full bg-background/70 text-muted-foreground hover:bg-muted hover:text-foreground"
        >
          <XIcon className="size-5" />
        </Link>

        {isEmpty ? (
          <div className="flex flex-1 flex-col items-center justify-center gap-4 px-6">
            <ScopeToggle scope={scope} />
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
              scope={scope}
            />

            {focused && (
              <FocusedView
                key={focused.id}
                session={focused}
                doneCount={doneCountFor(focused)}
                isBlockDone={(i) => isBlockDone(focused, i)}
                onToggleBlock={(i) => toggleBlock(focused, i)}
                onFinish={finishFocused}
                onSwap={() => setSwapOpen(true)}
                showAttribution={
                  currentUserId !== null && focused.trainerId !== currentUserId
                }
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

function ScopeToggle({ scope }: { scope: Scope }) {
  return (
    <div className="inline-flex rounded-full border border-border bg-muted p-0.5 text-xs">
      <Link
        href="/training_sessions"
        className={cn(
          "rounded-full px-3 py-1 font-medium transition",
          scope === "trainer"
            ? "bg-background text-foreground shadow-sm"
            : "text-muted-foreground hover:text-foreground",
        )}
      >
        Minhas
      </Link>
      <Link
        href="/training_sessions?scope=org"
        className={cn(
          "rounded-full px-3 py-1 font-medium transition",
          scope === "org"
            ? "bg-background text-foreground shadow-sm"
            : "text-muted-foreground hover:text-foreground",
        )}
      >
        Todas
      </Link>
    </div>
  )
}

function AvatarStrip({
  sessions,
  focusedId,
  onFocus,
  onAdd,
  doneCountFor,
  scope,
}: {
  sessions: TrainingSessionRow[]
  focusedId: string | null
  onFocus: (id: string) => void
  onAdd: () => void
  doneCountFor: (session: TrainingSessionRow) => number
  scope: Scope
}) {
  return (
    <div className="sticky top-0 z-10 border-b border-border bg-background/95 backdrop-blur">
      <div className="flex items-center justify-between px-3 pt-2">
        <ScopeToggle scope={scope} />
      </div>
      <div className="flex gap-2 overflow-x-auto px-3 py-3 pr-12">
        {sessions.map((session) => {
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
                  ? "border-primary bg-primary text-primary-foreground shadow"
                  : "border-border bg-card text-foreground/80",
                session.stale && "opacity-60",
              )}
            >
              <div className="relative">
                <ProgressRing pct={pct} active={isActive} stale={session.stale}>
                  <div
                    className={cn(
                      "flex h-11 w-11 items-center justify-center rounded-full text-sm font-semibold text-white",
                      paletteColorFor(session.student.id),
                    )}
                  >
                    {initials(session.student.name)}
                  </div>
                </ProgressRing>
                {session.stale && (
                  <span
                    aria-label="Sessão antiga"
                    className="absolute -right-0.5 -bottom-0.5 inline-flex size-4 items-center justify-center rounded-full bg-muted-foreground text-background shadow"
                  >
                    <ClockIcon className="size-3" />
                  </span>
                )}
              </div>
              <span className="text-[10px] leading-none">
                {session.student.name.split(/\s+/)[0]}
              </span>
              <span
                className={cn(
                  "text-[10px] leading-none",
                  isActive ? "text-primary-foreground/80" : "text-muted-foreground",
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
          className="flex shrink-0 flex-col items-center justify-center gap-1 rounded-2xl border border-dashed border-border px-3 text-muted-foreground/70 hover:border-foreground/40 hover:text-foreground"
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
  stale = false,
  children,
}: {
  pct: number
  active: boolean
  stale?: boolean
  children: React.ReactNode
}) {
  const ringColor = stale ? "rgb(156 163 175)" : "rgb(16 185 129)"
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
  showAttribution,
}: {
  session: TrainingSessionRow
  doneCount: number
  isBlockDone: (index: number) => boolean
  onToggleBlock: (index: number) => void
  onFinish: () => void
  onSwap: () => void
  showAttribution: boolean
}) {
  const total = session.blocks.length
  const pct = total > 0 ? Math.round((doneCount / total) * 100) : 0
  const [staleDismissed, setStaleDismissed] = useState(false)

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 pb-24">
      {session.stale && !staleDismissed && (
        <StaleBanner
          createdAt={session.createdAt}
          onFinish={onFinish}
          onDismiss={() => setStaleDismissed(true)}
        />
      )}
      <div className="mb-4 flex items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <div
            className={cn(
              "flex size-10 shrink-0 items-center justify-center rounded-full text-sm font-semibold text-white",
              paletteColorFor(session.student.id),
            )}
          >
            {initials(session.student.name)}
          </div>
          <div className="flex flex-col">
            <h1 className="text-lg font-semibold text-foreground">
              {session.student.name}
            </h1>
            <p className="text-sm text-muted-foreground">{session.workoutName}</p>
            {showAttribution && (
              <p className="text-xs text-muted-foreground">
                Iniciado por {session.trainerName}
              </p>
            )}
            <p className="text-xs text-muted-foreground">
              {doneCount} de {total} blocos · {pct}%
            </p>
          </div>
        </div>
        <div className="flex flex-col items-end gap-2">
          {session.finishedAt ? (
            <Button type="button" variant="outline" onClick={onFinish}>
              Reabrir
            </Button>
          ) : (
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button type="button">Finalizar</Button>
              </AlertDialogTrigger>
              <AlertDialogContent size="sm">
                <AlertDialogHeader>
                  <AlertDialogTitle>Finalizar sessão?</AlertDialogTitle>
                  <AlertDialogDescription>
                    {doneCount === 0
                      ? "Nenhum bloco foi marcado como feito. "
                      : `Você marcou ${doneCount} de ${total} blocos como feitos. `}
                    Você pode reabrir a sessão depois se precisar.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancelar</AlertDialogCancel>
                  <AlertDialogAction onClick={onFinish}>
                    Finalizar
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          )}
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
        <p className="rounded-2xl border border-dashed bg-card p-6 text-center text-sm text-muted-foreground">
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

function StaleBanner({
  createdAt,
  onFinish,
  onDismiss,
}: {
  createdAt: string
  onFinish: () => void
  onDismiss: () => void
}) {
  const hours = Math.max(1, Math.round((Date.now() - Date.parse(createdAt)) / 3_600_000))
  return (
    <div
      role="status"
      className="mb-3 flex items-start gap-3 rounded-2xl border border-amber-200 bg-amber-50 p-3 text-amber-900"
    >
      <ClockIcon className="mt-0.5 size-5 shrink-0" />
      <div className="flex flex-1 flex-col gap-2">
        <p className="text-sm">
          Esta sessão foi iniciada há {hours} {hours === 1 ? "hora" : "horas"}. Finalizar?
        </p>
        <div className="flex gap-2">
          <Button type="button" size="sm" onClick={onFinish}>
            Finalizar
          </Button>
          <Button type="button" size="sm" variant="ghost" onClick={onDismiss}>
            Mais tarde
          </Button>
        </div>
      </div>
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
        "block w-full rounded-2xl border p-3 text-left",
        "transition-[background-color,border-color,box-shadow,transform] duration-200 ease-out",
        "motion-safe:active:scale-95",
        done
          ? "border-emerald-500 bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
          : "border-border bg-card text-foreground hover:border-foreground/20",
      )}
    >
      {block.kind === "exercise" && <ExerciseCard block={block} done={done} />}
      {block.kind === "group" && <GroupCard block={block} done={done} />}
      {block.kind === "freeform" && <FreeformCard block={block} done={done} />}
    </button>
  )
}

function ExerciseCard({ block, done }: { block: ExerciseBlock; done: boolean }) {
  const muted = done ? "text-white/85" : "text-foreground/80"
  const fine = done ? "text-white/70" : "text-muted-foreground"
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
  const muted = done ? "text-white/85" : "text-foreground/80"
  const fine = done ? "text-white/70" : "text-muted-foreground"
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
        {block.textMd}
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
              Nenhum aluno disponível.
            </p>
          ) : (
            candidates.map((candidate) =>
              candidate.eligible ? (
                <button
                  key={candidate.id}
                  type="button"
                  onClick={() => onPick(candidate.id)}
                  className="flex h-12 items-center justify-between rounded-xl border border-transparent bg-card px-3 text-left text-sm font-medium text-foreground transition hover:bg-muted active:scale-[0.98]"
                >
                  {candidate.name}
                </button>
              ) : (
                <div
                  key={candidate.id}
                  aria-disabled="true"
                  className="flex min-h-12 flex-col justify-center rounded-xl border border-transparent bg-muted/40 px-3 py-2 text-left text-sm text-muted-foreground/70"
                >
                  <span className="font-medium">{candidate.name}</span>
                  {candidate.ineligibleReason && (
                    <span className="text-xs text-muted-foreground/70">
                      {INELIGIBLE_REASON_LABELS[candidate.ineligibleReason]}
                    </span>
                  )}
                </div>
              ),
            )
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
            <p className="text-sm text-foreground/80">
              O progresso atual será perdido. Continuar?
            </p>
            <p className="text-xs text-muted-foreground">
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
                        : "bg-card text-foreground hover:bg-muted active:scale-[0.98]",
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
      className="fixed inset-x-0 bottom-6 z-30 mx-auto w-fit max-w-[90%] rounded-full bg-foreground px-4 py-2 text-sm font-medium text-background shadow-lg"
    >
      {visible}
    </div>
  )
}
