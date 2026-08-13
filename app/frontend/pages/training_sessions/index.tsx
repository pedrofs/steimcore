import { Head, Link, router, usePage } from "@inertiajs/react"
import { ClockIcon, MoreVerticalIcon, PlusIcon, XIcon } from "lucide-react"
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
import { BlockEditSheet } from "@/components/blocks/block-edit-sheet"
import { BLOCK_KIND_LABELS } from "@/components/blocks/block-fields"
import { ExerciseMedia } from "@/components/exercise-media"
import { Button } from "@/components/ui/button"
import { ButtonGroup } from "@/components/ui/button-group"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { WeightControl } from "@/components/weight-control"
import { useBlocksDraft, type OriginIndex } from "@/hooks/use-blocks-draft"
import type {
  Block,
  ExerciseBlock,
  FreeformBlock,
  GroupBlock,
} from "@/lib/blocks"
import { type EditableBlock, toBlock } from "@/lib/blocks-draft"
import type { ExerciseSuggestion } from "@/lib/exercise-suggestions"
import { cn, normalizeForSearch } from "@/lib/utils"

import { initials, paletteColorFor } from "./avatar"

type TrainingSessionRow = {
  id: string
  student: { id: string; name: string }
  workoutId: string | null
  workoutName: string
  workoutPosition: number
  blocks: Block[]
  blocksDigest: string
  completedBlockIndices: string[]
  finishedAt: string | null
  createdAt: string
  stale: boolean
  trainerId: number | null
  trainerName: string | null
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
  exerciseSuggestions: ExerciseSuggestion[]
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
  exerciseSuggestions,
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

  const setLoad = useCallback(
    (session: TrainingSessionRow, exerciseName: string, value: string) => {
      router.post(
        `/training_sessions/${session.id}/exercise_loads`,
        { exerciseName, value },
        TOGGLE_RELOAD,
      )
    },
    [],
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

  function removeFocused() {
    if (!focused) return
    router.delete(`/training_sessions/${focused.id}`, PICKER_RELOAD)
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

  function claimFocused() {
    if (!focused) return
    router.post(`/training_sessions/${focused.id}/claim`, {}, TOGGLE_RELOAD)
  }

  return (
    <>
      <Head title="Sessões ao vivo" />
      <FlashToaster />
      <div className="relative flex min-h-screen flex-col bg-muted/30">
        <Link
          href="/"
          aria-label="Fechar"
          className="absolute top-[calc(env(safe-area-inset-top)+0.75rem)] right-3 z-20 inline-flex size-9 items-center justify-center rounded-full bg-background/70 text-muted-foreground hover:bg-muted hover:text-foreground"
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
                onSetLoad={(name, value) => setLoad(focused, name, value)}
                onFinish={finishFocused}
                onRemove={removeFocused}
                onSwap={() => setSwapOpen(true)}
                onClaim={claimFocused}
                canClaim={
                  currentUserId !== null && focused.trainerId !== currentUserId
                }
                showAttribution={
                  currentUserId !== null && focused.trainerId !== currentUserId
                }
                exerciseSuggestions={exerciseSuggestions}
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
    <div className="sticky top-0 z-10 border-b border-border bg-background/95 pt-[env(safe-area-inset-top)] backdrop-blur">
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
  onSetLoad,
  onFinish,
  onRemove,
  onSwap,
  onClaim,
  canClaim,
  showAttribution,
  exerciseSuggestions,
}: {
  session: TrainingSessionRow
  doneCount: number
  isBlockDone: (index: number) => boolean
  onToggleBlock: (index: number) => void
  onSetLoad: (exerciseName: string, value: string) => void
  onFinish: () => void
  onRemove: () => void
  onSwap: () => void
  onClaim: () => void
  canClaim: boolean
  showAttribution: boolean
  exerciseSuggestions: ExerciseSuggestion[]
}) {
  const total = session.blocks.length
  const pct = total > 0 ? Math.round((doneCount / total) * 100) : 0
  const [staleDismissed, setStaleDismissed] = useState(false)
  const [removeOpen, setRemoveOpen] = useState(false)
  const canSwap = session.swapOptions.length > 0

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
                {session.trainerName
                  ? `Iniciado por ${session.trainerName}`
                  : "Iniciado pelo aluno"}
              </p>
            )}
            <p className="text-xs text-muted-foreground">
              {doneCount} de {total} blocos · {pct}%
            </p>
          </div>
        </div>
        <div className="shrink-0">
          {session.finishedAt ? (
            <Button type="button" variant="outline" onClick={onFinish}>
              Reabrir
            </Button>
          ) : (
            <>
              <ButtonGroup>
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

                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button type="button" size="icon" aria-label="Mais ações">
                      <MoreVerticalIcon />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    {canClaim && (
                      <DropdownMenuItem onSelect={onClaim}>
                        Assumir aluno
                      </DropdownMenuItem>
                    )}
                    {canSwap && (
                      <DropdownMenuItem onSelect={onSwap}>
                        Trocar treino
                      </DropdownMenuItem>
                    )}
                    <DropdownMenuItem
                      variant="destructive"
                      onSelect={() => setRemoveOpen(true)}
                    >
                      Remover da pista
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </ButtonGroup>

              <AlertDialog open={removeOpen} onOpenChange={setRemoveOpen}>
                <AlertDialogContent size="sm">
                  <AlertDialogHeader>
                    <AlertDialogTitle>Remover da pista?</AlertDialogTitle>
                    <AlertDialogDescription>
                      A sessão será apagada e não aparecerá no histórico do aluno.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancelar</AlertDialogCancel>
                    <AlertDialogAction onClick={onRemove}>
                      Remover
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </>
          )}
        </div>
      </div>

      {/* Keyed by the digest so any server-side change to the blocks — a swap,
          another trainer's edit, or this trainer's own save — re-seeds the
          draft, while the block-completion round-trips (which leave the digest
          alone) keep a staged draft alive. */}
      <BlockList
        key={session.blocksDigest}
        session={session}
        isBlockDone={isBlockDone}
        onToggleBlock={onToggleBlock}
        onSetLoad={onSetLoad}
        canEdit={session.finishedAt === null}
        exerciseSuggestions={exerciseSuggestions}
      />
    </div>
  )
}

// The focused session's blocks, plus the **Mid-session edit** (ADR-0009): each
// card offers Editar / Remover, changes are staged locally in a draft, and the
// whole blocks array is committed once from the sticky bar. The first staged
// change puts the view into edit mode, where a card is no longer
// tap-to-complete — so a tap is never ambiguous between "mark done" and
// "select to edit", and a block staged for removal can never be ticked.
function BlockList({
  session,
  isBlockDone,
  onToggleBlock,
  onSetLoad,
  canEdit,
  exerciseSuggestions,
}: {
  session: TrainingSessionRow
  isBlockDone: (index: number) => boolean
  onToggleBlock: (index: number) => void
  onSetLoad: (exerciseName: string, value: string) => void
  canEdit: boolean
  exerciseSuggestions: ExerciseSuggestion[]
}) {
  const draft = useBlocksDraft(session.blocks)
  const [editingIndex, setEditingIndex] = useState<number | null>(null)
  const [saving, setSaving] = useState(false)
  const editMode = draft.dirty

  const cards = useMemo(
    () =>
      draft.blocks.map((block, index) => {
        const origin = draft.originIndices[index]
        return {
          block: withDecorations(toBlock(block), origin, session.blocks),
          origin,
        }
      }),
    [draft.blocks, draft.originIndices, session.blocks],
  )

  function discard() {
    setEditingIndex(null)
    draft.reset()
  }

  // Adding and editing are one gesture: the new block lands at the end of the
  // draft — the index it will hold once the append is applied — and the sheet
  // opens straight onto it.
  function addBlock(kind: EditableBlock["kind"]) {
    setEditingIndex(draft.blocks.length)
    if (kind === "exercise") draft.appendExercise()
    else if (kind === "group") draft.appendGroup()
    else draft.appendFreeform()
  }

  function save() {
    const { blocks, originIndices } = draft.payload()
    setSaving(true)
    router.patch(
      `/training_sessions/${session.id}/workout`,
      {
        workout: { blocks },
        // A blank entry, not null: Rails compacts nils out of parameter arrays,
        // which would silently shift every later block's origin.
        origin_indices: originIndices.map((origin) => (origin === null ? "" : origin)),
        blocks_digest: session.blocksDigest,
      },
      { preserveScroll: true, preserveState: true, onFinish: () => setSaving(false) },
    )
  }

  // The sheet stays mounted while it animates out, like the board's other
  // sheets, so it keeps rendering the block it was editing after the index is
  // cleared.
  const lastEditedIndex = useRef(0)
  if (editingIndex !== null) lastEditedIndex.current = editingIndex
  const sheetIndex = editingIndex ?? lastEditedIndex.current
  const sheetBlock = draft.blocks[sheetIndex]

  return (
    <>
      {cards.length === 0 ? (
        <p className="rounded-2xl border border-dashed bg-card p-6 text-center text-sm text-muted-foreground">
          Esse treino não tem blocos.
        </p>
      ) : (
        <div className="space-y-2">
          {cards.map(({ block, origin }, index) => (
            <BlockCard
              key={index}
              block={block}
              done={origin !== null && isBlockDone(origin)}
              editMode={editMode}
              onToggle={() => {
                if (origin !== null) onToggleBlock(origin)
              }}
              onSetLoad={onSetLoad}
              onEdit={canEdit ? () => setEditingIndex(index) : undefined}
              onRemove={canEdit ? () => draft.removeBlock(index) : undefined}
              onMoveUp={
                canEdit && index > 0 ? () => draft.moveBlock(index, -1) : undefined
              }
              onMoveDown={
                canEdit && index < cards.length - 1
                  ? () => draft.moveBlock(index, 1)
                  : undefined
              }
            />
          ))}
        </div>
      )}

      {canEdit && <AddBlockMenu onAdd={addBlock} />}

      {sheetBlock && (
        <BlockEditSheet
          open={editingIndex !== null}
          onOpenChange={(next) => {
            if (!next) setEditingIndex(null)
          }}
          block={sheetBlock}
          index={sheetIndex}
          draft={draft}
          suggestions={exerciseSuggestions}
        />
      )}

      {editMode && (
        <div className="fixed inset-x-0 bottom-0 z-30 border-t border-border bg-background/95 px-3 pt-3 pb-[calc(env(safe-area-inset-bottom)+0.75rem)] backdrop-blur">
          <div className="mx-auto flex max-w-2xl items-stretch gap-2">
            <Button
              type="button"
              variant="outline"
              className="h-auto px-4"
              onClick={discard}
              disabled={saving}
            >
              Descartar
            </Button>
            <Button
              type="button"
              className="h-auto flex-1 flex-col gap-0 py-2 leading-tight"
              onClick={save}
              disabled={saving}
            >
              <span>{saving ? "Salvando..." : "Salvar alterações"}</span>
              <span className="text-[11px] font-normal opacity-80">
                Vale também para os próximos treinos
              </span>
            </Button>
          </div>
        </div>
      )}
    </>
  )
}

// The block list's add affordance. A menu rather than three side-by-side
// buttons: the board is phone-first, and one full-width target is easier to hit
// one-handed than a row of them. Labels come from the inline editor's so the
// vocabulary is identical on both surfaces.
function AddBlockMenu({ onAdd }: { onAdd: (kind: EditableBlock["kind"]) => void }) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          type="button"
          variant="outline"
          className="mt-2 h-11 w-full gap-2 border-dashed text-muted-foreground"
        >
          <PlusIcon className="size-4" />
          Adicionar bloco
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        <DropdownMenuItem onSelect={() => onAdd("exercise")}>
          {BLOCK_KIND_LABELS.exercise}
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={() => onAdd("group")}>
          {BLOCK_KIND_LABELS.group}
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={() => onAdd("freeform")}>
          {BLOCK_KIND_LABELS.freeform}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

// A draft block is rebuilt from the editable mirror, which carries none of the
// media and weight the serializer decorates the server blocks with. Re-attach
// them from the block this one came from, but only while the movement's name is
// unchanged — a renamed exercise is a genuine substitution, and must not
// inherit the previous movement's load (ADR-0009).
function withDecorations(
  block: Block,
  origin: OriginIndex,
  serverBlocks: Block[],
): Block {
  const source = origin === null ? null : serverBlocks[origin]
  if (!source || source.kind !== block.kind) return block

  if (block.kind === "exercise" && source.kind === "exercise") {
    if (block.name !== source.name) return block
    return { ...block, weight: source.weight, media: source.media }
  }

  if (block.kind === "group" && source.kind === "group") {
    return {
      ...block,
      items: block.items.map((item, index) => {
        const sourceItem = source.items[index]
        if (!sourceItem || sourceItem.name !== item.name) return item
        return { ...item, weight: sourceItem.weight, media: sourceItem.media }
      }),
    }
  }

  return block
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
  editMode,
  onToggle,
  onSetLoad,
  onEdit,
  onRemove,
  onMoveUp,
  onMoveDown,
}: {
  block: Block
  done: boolean
  editMode: boolean
  onToggle: () => void
  onSetLoad: (exerciseName: string, value: string) => void
  onEdit?: () => void
  onRemove?: () => void
  onMoveUp?: () => void
  onMoveDown?: () => void
}) {
  return (
    <button
      type="button"
      onClick={editMode ? undefined : onToggle}
      aria-pressed={done}
      className={cn(
        "block w-full rounded-2xl border p-3 text-left",
        "transition-[background-color,border-color,box-shadow,transform] duration-200 ease-out",
        !editMode && "motion-safe:active:scale-95",
        done
          ? "border-emerald-500 bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
          : "border-border bg-card text-foreground hover:border-foreground/20",
      )}
    >
      <div className="flex items-start gap-2">
        <div className="min-w-0 flex-1">
          {block.kind === "exercise" && (
            <ExerciseCard block={block} done={done} onSetLoad={onSetLoad} />
          )}
          {block.kind === "group" && (
            <GroupCard block={block} done={done} onSetLoad={onSetLoad} />
          )}
          {block.kind === "freeform" && <FreeformCard block={block} done={done} />}
        </div>
        {onEdit && onRemove && (
          <BlockMenu
            done={done}
            onEdit={onEdit}
            onRemove={onRemove}
            onMoveUp={onMoveUp}
            onMoveDown={onMoveDown}
          />
        )}
      </div>
    </button>
  )
}

// A span trigger rather than a button — the card itself is a button, and the
// board already nests its media and weight affordances the same way. Stops
// propagation so opening the menu never toggles the block.
function BlockMenu({
  done,
  onEdit,
  onRemove,
  onMoveUp,
  onMoveDown,
}: {
  done: boolean
  onEdit: () => void
  onRemove: () => void
  onMoveUp?: () => void
  onMoveDown?: () => void
}) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <span
          role="button"
          tabIndex={0}
          aria-label="Opções do bloco"
          onClick={(event) => event.stopPropagation()}
          className={cn(
            "-mt-1 -mr-1 inline-flex size-8 shrink-0 cursor-pointer items-center justify-center rounded-full",
            done ? "text-white/80 hover:bg-white/15" : "text-muted-foreground hover:bg-muted",
          )}
        >
          <MoreVerticalIcon className="size-4" />
        </span>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onSelect={onEdit}>Editar</DropdownMenuItem>
        <DropdownMenuItem disabled={!onMoveUp} onSelect={() => onMoveUp?.()}>
          Mover para cima
        </DropdownMenuItem>
        <DropdownMenuItem disabled={!onMoveDown} onSelect={() => onMoveDown?.()}>
          Mover para baixo
        </DropdownMenuItem>
        <DropdownMenuItem variant="destructive" onSelect={onRemove}>
          Remover
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function ExerciseCard({
  block,
  done,
  onSetLoad,
}: {
  block: ExerciseBlock
  done: boolean
  onSetLoad: (exerciseName: string, value: string) => void
}) {
  const muted = done ? "text-white/85" : "text-foreground/80"
  const fine = done ? "text-white/70" : "text-muted-foreground"
  return (
    <div className="flex items-stretch gap-3">
      <ExerciseMedia name={block.name} media={block.media} className="self-center" />
      <div className="flex flex-1 flex-col gap-1">
        <div className="text-base font-medium">{block.name}</div>
        <div className={cn("text-sm", muted)}>{block.prescription}</div>
        {typeof block.restS === "number" && (
          <div className={cn("text-xs", fine)}>Descanso: {block.restS}s</div>
        )}
        {block.notes && <div className={cn("text-xs", fine)}>{block.notes}</div>}
      </div>
      <WeightControl
        variant="cell"
        exerciseName={block.name}
        weight={block.weight}
        onSubmit={(value) => onSetLoad(block.name, value)}
      />
    </div>
  )
}

function GroupCard({
  block,
  done,
  onSetLoad,
}: {
  block: GroupBlock
  done: boolean
  onSetLoad: (exerciseName: string, value: string) => void
}) {
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
      <ul className="flex flex-col gap-1.5 pl-3">
        {block.items.map((item, idx) => (
          <li key={idx} className="flex items-stretch gap-2">
            <ExerciseMedia
              name={item.name}
              media={item.media}
              className="size-9 self-center"
            />
            <span className={cn("flex-1 self-center text-sm", muted)}>
              <span className="font-medium">{item.name}</span>
              <span className={cn(fine)}> · {item.prescription}</span>
            </span>
            <WeightControl
              variant="cell"
              exerciseName={item.name}
              weight={item.weight}
              onSubmit={(value) => onSetLoad(item.name, value)}
            />
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
  const [query, setQuery] = useState("")

  useEffect(() => {
    if (!open) setQuery("")
  }, [open])

  const filteredCandidates = useMemo(() => {
    const needle = normalizeForSearch(query.trim())
    if (!needle) return candidates
    return candidates.filter((candidate) =>
      normalizeForSearch(candidate.name).includes(needle),
    )
  }, [candidates, query])

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="bottom"
        className="max-h-[min(80vh,calc(100dvh-var(--keyboard-h,0px)-env(safe-area-inset-top)-1rem))] overflow-y-auto"
      >
        <SheetHeader>
          <SheetTitle>Adicionar aluno</SheetTitle>
        </SheetHeader>
        <div className="flex flex-col gap-2 p-4 pt-0">
          {candidates.length > 0 && (
            <Input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Buscar aluno..."
              aria-label="Buscar aluno"
            />
          )}
          {candidates.length === 0 ? (
            <p className="rounded-xl border border-dashed bg-muted/20 p-6 text-center text-sm text-muted-foreground">
              Nenhum aluno disponível.
            </p>
          ) : filteredCandidates.length === 0 ? (
            <p className="rounded-xl border border-dashed bg-muted/20 p-6 text-center text-sm text-muted-foreground">
              Nenhum aluno encontrado.
            </p>
          ) : (
            filteredCandidates.map((candidate) =>
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
      <SheetContent
        side="bottom"
        className="max-h-[min(80vh,calc(100dvh-var(--keyboard-h,0px)-env(safe-area-inset-top)-1rem))] overflow-y-auto"
      >
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
  const { flash, errors } = usePage().props
  // One treatment for everything the server says back: the board's
  // confirmations ("Treino atualizado no plano do aluno."), its guard alerts,
  // and the pt-BR validation errors a rejected **Mid-session edit** returns as
  // an errors hash rather than a flash.
  const message = flash.alert ?? flash.notice ?? errorMessage(errors)
  const [visible, setVisible] = useState<string | null>(null)

  useEffect(() => {
    if (!message) return
    setVisible(message)
    const id = window.setTimeout(() => setVisible(null), 4000)
    return () => window.clearTimeout(id)
  }, [message])

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

function errorMessage(errors: Record<string, unknown>): string | undefined {
  const messages: string[] = []
  for (const value of Object.values(errors)) {
    if (Array.isArray(value)) {
      for (const entry of value) {
        if (typeof entry === "string") messages.push(entry)
      }
    } else if (typeof value === "string") {
      messages.push(value)
    }
  }
  return messages.length > 0 ? messages.join(" · ") : undefined
}
