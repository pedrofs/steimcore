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
  dense?: boolean
}

export function BlocksRenderer({ blocks, emptyPlaceholder, dense }: Props) {
  if (!blocks || blocks.length === 0) {
    if (!emptyPlaceholder) return null
    return (
      <p className="workout-blocks-empty rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
        {emptyPlaceholder}
      </p>
    )
  }

  if (dense) {
    return (
      <div className="workout-blocks flex flex-col">
        {blocks.map((block, index) => (
          <DenseBlockItem key={index} block={block} />
        ))}
      </div>
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

function DenseBlockItem({ block }: { block: Block }) {
  switch (block.kind) {
    case "exercise":
      return <DenseExerciseRow block={block} />
    case "group":
      return <DenseGroupRow block={block} />
    case "freeform":
      return <DenseFreeformBlock block={block} />
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
      <LoadCell />
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
            <LoadCell />
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

// Visible only on print: a blank cell the trainer pencils a load into per session.
function LoadCell() {
  return (
    <span className="exercise-load hidden print:flex print:items-baseline print:gap-1 print:mt-0.5 print:text-[8pt] print:text-neutral-700">
      <span className="uppercase tracking-wide">Carga:</span>
      <span className="inline-block flex-1 border-b border-neutral-500 min-w-[20mm]"></span>
    </span>
  )
}

function DenseExerciseRow({ block }: { block: ExerciseBlock }) {
  return (
    <div className="workout-block exercise-row flex flex-wrap items-baseline gap-x-1.5 py-px text-[8pt] leading-tight">
      <span className="exercise-name font-semibold">{block.name}</span>
      <span className="exercise-prescription text-neutral-700">
        {block.prescription}
      </span>
      {block.restS != null && (
        <span className="exercise-rest text-neutral-600">· {block.restS}s</span>
      )}
      {block.notes && (
        <span className="exercise-notes text-neutral-600 italic">
          · {block.notes}
        </span>
      )}
    </div>
  )
}

function DenseGroupRow({ block }: { block: GroupBlock }) {
  const header = [
    block.label,
    block.rounds != null ? `${block.rounds}x` : null,
  ]
    .filter(Boolean)
    .join(" · ")

  return (
    <div className="workout-block group py-px">
      {header.length > 0 && (
        <div className="group-header text-[7.5pt] font-semibold uppercase tracking-wide text-neutral-700 leading-tight">
          {header}
        </div>
      )}
      <div className="group-items flex flex-col">
        {block.items.map((item, i) => (
          <div
            key={i}
            className="group-item flex flex-wrap items-baseline gap-x-1.5 pl-2 text-[8pt] leading-tight"
          >
            <span className="font-semibold">{item.name}</span>
            <span className="text-neutral-700">{item.prescription}</span>
            {item.notes && (
              <span className="text-neutral-600 italic">· {item.notes}</span>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

function DenseFreeformBlock({ block }: { block: FreeformBlock }) {
  return (
    <div className="workout-block freeform py-px">
      <Markdown
        content={block.textMd}
        className="text-[8pt] leading-tight [&_h1]:text-[9pt] [&_h1]:font-semibold [&_h1]:my-0 [&_h2]:text-[8.5pt] [&_h2]:font-semibold [&_h2]:my-0 [&_h3]:text-[8pt] [&_h3]:font-semibold [&_h3]:my-0 [&_p]:my-0 [&_p]:leading-tight [&_ul]:my-0 [&_ul]:pl-3 [&_ol]:my-0 [&_ol]:pl-3 [&_li]:my-0 [&_li]:leading-tight [&_li>p]:my-0"
      />
    </div>
  )
}
