import { Head, Link, router } from "@inertiajs/react"
import { PlusIcon, XIcon } from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
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
}

type PickerCandidate = {
  id: string
  name: string
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

function reloadProps() {
  return {
    only: ["trainingSessions", "pickerCandidates"],
    preserveState: true,
    preserveScroll: true,
  } as const
}

export default function TrainingSessionsIndex({
  trainingSessions,
  pickerCandidates,
}: Props) {
  const [pickerOpen, setPickerOpen] = useState(false)
  const [focusedId, setFocusedId] = useState<string | null>(
    () => trainingSessions[0]?.id ?? null,
  )
  const prevIdsRef = useRef<string[]>(trainingSessions.map((s) => s.id))

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

  function addStudent(studentId: string) {
    setPickerOpen(false)
    router.post(
      "/training_sessions",
      { student_id: studentId },
      reloadProps(),
    )
  }

  function finishFocused() {
    if (!focused) return
    router.post(
      `/training_sessions/${focused.id}/completion`,
      {},
      reloadProps(),
    )
  }

  return (
    <>
      <Head title="Sessões ao vivo" />
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
            />

            {focused && (
              <FocusedView session={focused} onFinish={finishFocused} />
            )}
          </>
        )}

        <PickerSheet
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          candidates={pickerCandidates}
          onPick={addStudent}
        />
      </div>
    </>
  )
}

function AvatarStrip({
  sessions,
  focusedId,
  onFocus,
  onAdd,
}: {
  sessions: TrainingSessionRow[]
  focusedId: string | null
  onFocus: (id: string) => void
  onAdd: () => void
}) {
  return (
    <div className="sticky top-0 z-10 border-b border-neutral-200 bg-white/95 backdrop-blur">
      <div className="flex gap-2 overflow-x-auto px-3 py-3 pr-12">
        {sessions.map((session, index) => {
          const isActive = session.id === focusedId
          const done = session.completedBlockIndices.length
          const total = session.blocks.length
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
              <div
                className={cn(
                  "flex h-12 w-12 items-center justify-center rounded-full text-sm font-semibold text-white",
                  paletteColorFor(index),
                )}
              >
                {initials(session.student.name)}
              </div>
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

function FocusedView({
  session,
  onFinish,
}: {
  session: TrainingSessionRow
  onFinish: () => void
}) {
  const done = session.completedBlockIndices.length
  const total = session.blocks.length
  const pct = total > 0 ? Math.round((done / total) * 100) : 0

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 pb-24">
      <div className="mb-4 flex items-start justify-between gap-3">
        <div className="flex flex-col">
          <h1 className="text-lg font-semibold text-neutral-900">
            {session.student.name}
          </h1>
          <p className="text-sm text-neutral-600">{session.workoutName}</p>
          <p className="text-xs text-neutral-500">
            {done} de {total} blocos · {pct}%
          </p>
        </div>
        <Button
          type="button"
          variant={session.finishedAt ? "outline" : "default"}
          onClick={onFinish}
        >
          {session.finishedAt ? "Reabrir" : "Finalizar"}
        </Button>
      </div>

      {total === 0 ? (
        <p className="rounded-2xl border border-dashed bg-white p-6 text-center text-sm text-neutral-500">
          Esse treino não tem blocos.
        </p>
      ) : (
        <div className="space-y-2">
          {session.blocks.map((block, index) => (
            <BlockCard key={index} block={block} />
          ))}
        </div>
      )}
    </div>
  )
}

function BlockCard({ block }: { block: Block }) {
  return (
    <div className="rounded-2xl border border-neutral-200 bg-white p-3">
      {block.kind === "exercise" && <ExerciseCard block={block} />}
      {block.kind === "group" && <GroupCard block={block} />}
      {block.kind === "freeform" && <FreeformCard block={block} />}
    </div>
  )
}

function ExerciseCard({ block }: { block: ExerciseBlock }) {
  return (
    <div className="flex flex-col gap-1">
      <div className="text-base font-medium text-neutral-900">{block.name}</div>
      <div className="text-sm text-neutral-700">{block.prescription}</div>
      {typeof block.rest_s === "number" && (
        <div className="text-xs text-neutral-500">
          Descanso: {block.rest_s}s
        </div>
      )}
      {block.notes && (
        <div className="text-xs text-neutral-500">{block.notes}</div>
      )}
    </div>
  )
}

function GroupCard({ block }: { block: GroupBlock }) {
  const label = block.label?.trim() || "Grupo"
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between gap-2">
        <div className="text-base font-medium text-neutral-900">{label}</div>
        {typeof block.rounds === "number" && (
          <div className="text-xs font-medium text-neutral-500">
            {block.rounds} rounds
          </div>
        )}
      </div>
      <ul className="flex flex-col gap-1 pl-3">
        {block.items.map((item, idx) => (
          <li key={idx} className="text-sm text-neutral-700">
            <span className="font-medium">{item.name}</span>
            <span className="text-neutral-500"> · {item.prescription}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

const FREEFORM_COMPONENTS = {
  a: ({ children }: { children?: React.ReactNode }) => <span>{children}</span>,
  h1: ({ children }: { children?: React.ReactNode }) => (
    <p className="font-semibold text-neutral-900">{children}</p>
  ),
  h2: ({ children }: { children?: React.ReactNode }) => (
    <p className="font-semibold text-neutral-900">{children}</p>
  ),
  h3: ({ children }: { children?: React.ReactNode }) => (
    <p className="font-medium text-neutral-900">{children}</p>
  ),
}

function FreeformCard({ block }: { block: FreeformBlock }) {
  return (
    <div className="prose prose-sm prose-neutral max-w-none text-sm leading-relaxed">
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
