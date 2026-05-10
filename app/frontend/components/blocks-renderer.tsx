import { Markdown } from "@/components/markdown"

export type ExerciseBlock = {
  kind: "exercise"
  name: string
  prescription: string
  restS?: number
  notes?: string
}

export type GroupItem = {
  name: string
  prescription: string
  notes?: string
}

export type GroupBlock = {
  kind: "group"
  label?: string
  rounds?: number
  items: GroupItem[]
}

export type FreeformBlock = {
  kind: "freeform"
  textMd: string
}

export type Block = ExerciseBlock | GroupBlock | FreeformBlock

type Props = {
  blocks: Block[]
  emptyPlaceholder?: string
}

export function BlocksRenderer({ blocks, emptyPlaceholder }: Props) {
  if (!blocks || blocks.length === 0) {
    if (!emptyPlaceholder) return null
    return (
      <p className="workout-blocks-empty rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
        {emptyPlaceholder}
      </p>
    )
  }

  return (
    <div className="workout-blocks flex flex-col gap-3">
      {blocks.map((block, index) => (
        <BlockItem key={index} block={block} />
      ))}
    </div>
  )
}

function BlockItem({ block }: { block: Block }) {
  switch (block.kind) {
    case "exercise":
      return <ExerciseRow block={block} />
    case "group":
      return <GroupRow block={block} />
    case "freeform":
      return <FreeformBlockRow block={block} />
  }
}

function ExerciseRow({ block }: { block: ExerciseBlock }) {
  return (
    <div className="workout-block exercise-row flex flex-col gap-1 rounded-lg border bg-background p-3">
      <div className="exercise-row-header flex flex-wrap items-baseline justify-between gap-2">
        <span className="exercise-name text-sm font-medium">{block.name}</span>
        <span className="exercise-prescription text-sm text-muted-foreground">
          {block.prescription}
        </span>
      </div>
      {(block.restS != null || block.notes) && (
        <div className="exercise-meta flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
          {block.restS != null && (
            <span className="exercise-rest">descanso {block.restS}s</span>
          )}
          {block.notes && <span className="exercise-notes">{block.notes}</span>}
        </div>
      )}
    </div>
  )
}

function GroupRow({ block }: { block: GroupBlock }) {
  const header = [
    block.label,
    block.rounds != null ? `${block.rounds}x` : null,
  ]
    .filter(Boolean)
    .join(" · ")

  return (
    <div className="workout-block group rounded-lg border bg-muted/20 p-3">
      {header.length > 0 && (
        <div className="group-header mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {header}
        </div>
      )}
      <div className="group-items flex flex-col gap-1">
        {block.items.map((item, i) => (
          <div
            key={i}
            className="group-item flex flex-col gap-0.5 rounded-md bg-background p-2"
          >
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <span className="text-sm font-medium">{item.name}</span>
              <span className="text-sm text-muted-foreground">
                {item.prescription}
              </span>
            </div>
            {item.notes && (
              <span className="text-xs text-muted-foreground">{item.notes}</span>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

function FreeformBlockRow({ block }: { block: FreeformBlock }) {
  return (
    <div className="workout-block freeform rounded-lg border bg-background p-3">
      <Markdown content={block.textMd} />
    </div>
  )
}
