import { useForm } from "@inertiajs/react"
import { ArrowDownIcon, ArrowUpIcon, PlusIcon, XIcon } from "lucide-react"
import { useEffect, useMemo, useRef } from "react"

import type { Block, ExerciseBlock, FreeformBlock, GroupBlock, GroupItem } from "@/components/blocks-renderer"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"

type EditableExercise = {
  kind: "exercise"
  name: string
  prescription: string
  restS: string
  notes: string
}

type EditableGroupItem = {
  name: string
  prescription: string
  notes: string
}

type EditableGroup = {
  kind: "group"
  label: string
  rounds: string
  items: EditableGroupItem[]
}

type EditableFreeform = {
  kind: "freeform"
  textMd: string
}

type EditableBlock = EditableExercise | EditableGroup | EditableFreeform

type Props = {
  versionId: string
  workoutId: string
  blocks: Block[]
  onCancel: () => void
  onSaved: () => void
  onDirtyChange?: (dirty: boolean) => void
  returnTo?: string
}

export function WorkoutEditor({
  versionId,
  workoutId,
  blocks,
  onCancel,
  onSaved,
  onDirtyChange,
  returnTo,
}: Props) {
  const initialEditable = useMemo(() => blocks.map(toEditable), [blocks])
  const { data, patch, errors, setData, transform, processing } = useForm<{ blocks: EditableBlock[] }>({
    blocks: initialEditable,
  })

  const errorMessages = collectErrorMessages(errors)

  const dirty = useMemo(
    () => !blocksEqual(data.blocks, initialEditable),
    [data.blocks, initialEditable],
  )

  const onDirtyChangeRef = useRef(onDirtyChange)
  onDirtyChangeRef.current = onDirtyChange

  useEffect(() => {
    onDirtyChangeRef.current?.(dirty)
  }, [dirty])

  useEffect(() => {
    return () => {
      onDirtyChangeRef.current?.(false)
    }
  }, [])

  const setBlocks = (next: EditableBlock[]) => setData("blocks", next)

  const updateBlock = (index: number, partial: Partial<EditableBlock>) => {
    setBlocks(
      data.blocks.map((b, i) =>
        i === index ? ({ ...b, ...partial } as EditableBlock) : b,
      ),
    )
  }

  const removeBlock = (index: number) => {
    setBlocks(data.blocks.filter((_, i) => i !== index))
  }

  const moveBlock = (index: number, direction: -1 | 1) => {
    const target = index + direction
    if (target < 0 || target >= data.blocks.length) return
    const next = [...data.blocks]
    ;[next[index], next[target]] = [next[target], next[index]]
    setBlocks(next)
  }

  const appendExercise = () =>
    setBlocks([
      ...data.blocks,
      { kind: "exercise", name: "", prescription: "", restS: "", notes: "" },
    ])

  const appendGroup = () =>
    setBlocks([
      ...data.blocks,
      {
        kind: "group",
        label: "",
        rounds: "",
        items: [{ name: "", prescription: "", notes: "" }],
      },
    ])

  const appendFreeform = () =>
    setBlocks([
      ...data.blocks,
      { kind: "freeform", textMd: "" },
    ])

  const updateGroupItem = (
    blockIndex: number,
    itemIndex: number,
    partial: Partial<EditableGroupItem>,
  ) => {
    const block = data.blocks[blockIndex]
    if (block.kind !== "group") return
    const nextItems = block.items.map((item, i) =>
      i === itemIndex ? { ...item, ...partial } : item,
    )
    updateBlock(blockIndex, { items: nextItems } as Partial<EditableGroup>)
  }

  const appendGroupItem = (blockIndex: number) => {
    const block = data.blocks[blockIndex]
    if (block.kind !== "group") return
    const nextItems = [
      ...block.items,
      { name: "", prescription: "", notes: "" },
    ]
    updateBlock(blockIndex, { items: nextItems } as Partial<EditableGroup>)
  }

  const removeGroupItem = (blockIndex: number, itemIndex: number) => {
    const block = data.blocks[blockIndex]
    if (block.kind !== "group") return
    if (block.items.length <= 1) return
    const nextItems = block.items.filter((_, i) => i !== itemIndex)
    updateBlock(blockIndex, { items: nextItems } as Partial<EditableGroup>)
  }

  const moveGroupItem = (
    blockIndex: number,
    itemIndex: number,
    direction: -1 | 1,
  ) => {
    const block = data.blocks[blockIndex]
    if (block.kind !== "group") return
    const target = itemIndex + direction
    if (target < 0 || target >= block.items.length) return
    const nextItems = [...block.items]
    ;[nextItems[itemIndex], nextItems[target]] = [
      nextItems[target],
      nextItems[itemIndex],
    ]
    updateBlock(blockIndex, { items: nextItems } as Partial<EditableGroup>)
  }

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    transform((data) => {
      const payload: Record<string, unknown> = {
        workout: { blocks: data.blocks.map(toBlock) },
      }
      if (returnTo) payload.return_to = returnTo
      return payload
    })
    patch(`/periodization_versions/${versionId}/workouts/${workoutId}`, {
      preserveScroll: true,
      onSuccess: onSaved,
    })
  }

  const blockCount = data.blocks.length

  return (
    <form onSubmit={submit} className="flex flex-col gap-4">
      {errorMessages.length > 0 && (
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-3 text-sm">
          <p className="font-medium">Não foi possível salvar:</p>
          <ul className="mt-1 list-inside list-disc">
            {errorMessages.map((msg, i) => (
              <li key={i}>{msg}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {data.blocks.map((block, index) => (
          <BlockEditor
            key={index}
            block={block}
            isFirst={index === 0}
            isLast={index === blockCount - 1}
            onChange={(partial) => updateBlock(index, partial)}
            onMoveUp={() => moveBlock(index, -1)}
            onMoveDown={() => moveBlock(index, 1)}
            onRemove={() => removeBlock(index)}
            onItemChange={(itemIndex, partial) =>
              updateGroupItem(index, itemIndex, partial)
            }
            onItemAppend={() => appendGroupItem(index)}
            onItemRemove={(itemIndex) => removeGroupItem(index, itemIndex)}
            onItemMoveUp={(itemIndex) => moveGroupItem(index, itemIndex, -1)}
            onItemMoveDown={(itemIndex) => moveGroupItem(index, itemIndex, 1)}
          />
        ))}
      </div>

      <AddBlockButtons
        onAddExercise={appendExercise}
        onAddGroup={appendGroup}
        onAddFreeform={appendFreeform}
      />

      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button
          type="button"
          variant="outline"
          className="h-11 sm:h-10"
          onClick={onCancel}
        >
          Cancelar
        </Button>
        <Button type="submit" disabled={processing} className="h-11 sm:h-10">
          {processing ? "Salvando..." : "Salvar treino"}
        </Button>
      </div>
    </form>
  )
}

function AddBlockButtons({
  onAddExercise,
  onAddGroup,
  onAddFreeform,
}: {
  onAddExercise: () => void
  onAddGroup: () => void
  onAddFreeform: () => void
}) {
  return (
    <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">
      <Button
        type="button"
        variant="outline"
        className="h-11 gap-2 sm:h-10"
        onClick={onAddExercise}
      >
        <PlusIcon className="size-4" />
        Exercício
      </Button>
      <Button
        type="button"
        variant="outline"
        className="h-11 gap-2 sm:h-10"
        onClick={onAddGroup}
      >
        <PlusIcon className="size-4" />
        Grupo
      </Button>
      <Button
        type="button"
        variant="outline"
        className="h-11 gap-2 sm:h-10"
        onClick={onAddFreeform}
      >
        <PlusIcon className="size-4" />
        Texto livre
      </Button>
    </div>
  )
}

type BlockEditorProps = {
  block: EditableBlock
  isFirst: boolean
  isLast: boolean
  onChange: (partial: Partial<EditableBlock>) => void
  onMoveUp: () => void
  onMoveDown: () => void
  onRemove: () => void
  onItemChange: (itemIndex: number, partial: Partial<EditableGroupItem>) => void
  onItemAppend: () => void
  onItemRemove: (itemIndex: number) => void
  onItemMoveUp: (itemIndex: number) => void
  onItemMoveDown: (itemIndex: number) => void
}

function BlockEditor({
  block,
  isFirst,
  isLast,
  onChange,
  onMoveUp,
  onMoveDown,
  onRemove,
  onItemChange,
  onItemAppend,
  onItemRemove,
  onItemMoveUp,
  onItemMoveDown,
}: BlockEditorProps) {
  const controls = (
    <BlockControls
      isFirst={isFirst}
      isLast={isLast}
      onMoveUp={onMoveUp}
      onMoveDown={onMoveDown}
      onRemove={onRemove}
    />
  )
  switch (block.kind) {
    case "exercise":
      return <ExerciseBlockEditor block={block} onChange={onChange} controls={controls} />
    case "group":
      return (
        <GroupBlockEditor
          block={block}
          onChange={onChange}
          onItemChange={onItemChange}
          onItemAppend={onItemAppend}
          onItemRemove={onItemRemove}
          onItemMoveUp={onItemMoveUp}
          onItemMoveDown={onItemMoveDown}
          controls={controls}
        />
      )
    case "freeform":
      return <FreeformBlockEditor block={block} onChange={onChange} controls={controls} />
  }
}

function BlockControls({
  isFirst,
  isLast,
  onMoveUp,
  onMoveDown,
  onRemove,
}: {
  isFirst: boolean
  isLast: boolean
  onMoveUp: () => void
  onMoveDown: () => void
  onRemove: () => void
}) {
  return (
    <div className="flex items-center gap-1">
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="size-8"
        disabled={isFirst}
        onClick={onMoveUp}
        aria-label="Mover bloco para cima"
      >
        <ArrowUpIcon className="size-4" />
      </Button>
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="size-8"
        disabled={isLast}
        onClick={onMoveDown}
        aria-label="Mover bloco para baixo"
      >
        <ArrowDownIcon className="size-4" />
      </Button>
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="size-8"
        onClick={onRemove}
        aria-label="Remover bloco"
      >
        <XIcon className="size-4" />
      </Button>
    </div>
  )
}

function BlockHeader({
  label,
  controls,
}: {
  label: string
  controls: React.ReactNode
}) {
  return (
    <div className="mb-2 flex items-center justify-between gap-2">
      <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {label}
      </p>
      {controls}
    </div>
  )
}

function ExerciseBlockEditor({
  block,
  onChange,
  controls,
}: {
  block: EditableExercise
  onChange: (partial: Partial<EditableExercise>) => void
  controls: React.ReactNode
}) {
  return (
    <div className="rounded-lg border bg-background p-3">
      <BlockHeader label="Exercício" controls={controls} />
      <div className="grid gap-2 sm:grid-cols-2">
        <FieldRow label="Nome">
          <Input
            value={block.name}
            onChange={(e) => onChange({ name: e.target.value })}
          />
        </FieldRow>
        <FieldRow label="Prescrição">
          <Input
            value={block.prescription}
            onChange={(e) => onChange({ prescription: e.target.value })}
            placeholder="ex.: 3 × 8-10"
          />
        </FieldRow>
        <FieldRow label="Descanso (s)">
          <Input
            type="number"
            inputMode="numeric"
            min={0}
            value={block.restS}
            onChange={(e) => onChange({ restS: e.target.value })}
          />
        </FieldRow>
        <FieldRow label="Observações">
          <Input
            value={block.notes}
            onChange={(e) => onChange({ notes: e.target.value })}
          />
        </FieldRow>
      </div>
    </div>
  )
}

function GroupBlockEditor({
  block,
  onChange,
  onItemChange,
  onItemAppend,
  onItemRemove,
  onItemMoveUp,
  onItemMoveDown,
  controls,
}: {
  block: EditableGroup
  onChange: (partial: Partial<EditableGroup>) => void
  onItemChange: (itemIndex: number, partial: Partial<EditableGroupItem>) => void
  onItemAppend: () => void
  onItemRemove: (itemIndex: number) => void
  onItemMoveUp: (itemIndex: number) => void
  onItemMoveDown: (itemIndex: number) => void
  controls: React.ReactNode
}) {
  const itemCount = block.items.length
  return (
    <div className="rounded-lg border bg-muted/20 p-3">
      <BlockHeader label="Grupo" controls={controls} />
      <div className="grid gap-2 sm:grid-cols-2">
        <FieldRow label="Rótulo">
          <Input
            value={block.label}
            onChange={(e) => onChange({ label: e.target.value })}
            placeholder="ex.: Superset A"
          />
        </FieldRow>
        <FieldRow label="Rodadas">
          <Input
            type="number"
            inputMode="numeric"
            min={0}
            value={block.rounds}
            onChange={(e) => onChange({ rounds: e.target.value })}
          />
        </FieldRow>
      </div>
      <div className="mt-3 flex flex-col gap-2">
        {block.items.map((item, itemIndex) => (
          <div key={itemIndex} className="rounded-md border bg-background p-2">
            <div className="mb-1 flex items-center justify-between gap-2">
              <p className="text-xs font-medium text-muted-foreground">
                Item {itemIndex + 1}
              </p>
              <div className="flex items-center gap-1">
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="size-7"
                  disabled={itemIndex === 0}
                  onClick={() => onItemMoveUp(itemIndex)}
                  aria-label="Mover item para cima"
                >
                  <ArrowUpIcon className="size-4" />
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="size-7"
                  disabled={itemIndex === itemCount - 1}
                  onClick={() => onItemMoveDown(itemIndex)}
                  aria-label="Mover item para baixo"
                >
                  <ArrowDownIcon className="size-4" />
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="size-7"
                  disabled={itemCount <= 1}
                  onClick={() => onItemRemove(itemIndex)}
                  aria-label="Remover item"
                >
                  <XIcon className="size-4" />
                </Button>
              </div>
            </div>
            <div className="grid gap-2 sm:grid-cols-2">
              <FieldRow label="Nome">
                <Input
                  value={item.name}
                  onChange={(e) =>
                    onItemChange(itemIndex, { name: e.target.value })
                  }
                />
              </FieldRow>
              <FieldRow label="Prescrição">
                <Input
                  value={item.prescription}
                  onChange={(e) =>
                    onItemChange(itemIndex, { prescription: e.target.value })
                  }
                />
              </FieldRow>
              <FieldRow label="Observações">
                <Input
                  value={item.notes}
                  onChange={(e) =>
                    onItemChange(itemIndex, { notes: e.target.value })
                  }
                />
              </FieldRow>
            </div>
          </div>
        ))}
        <Button
          type="button"
          variant="outline"
          className="h-10 gap-2 self-start"
          onClick={onItemAppend}
        >
          <PlusIcon className="size-4" />
          Adicionar item
        </Button>
      </div>
    </div>
  )
}

function FreeformBlockEditor({
  block,
  onChange,
  controls,
}: {
  block: EditableFreeform
  onChange: (partial: Partial<EditableFreeform>) => void
  controls: React.ReactNode
}) {
  return (
    <div className="rounded-lg border bg-background p-3">
      <BlockHeader label="Texto livre" controls={controls} />
      <Textarea
        value={block.textMd}
        onChange={(e) => onChange({ textMd: e.target.value })}
        rows={5}
        className="min-h-24 font-mono text-sm"
      />
    </div>
  )
}

function FieldRow({
  label,
  children,
}: {
  label: string
  children: React.ReactNode
}) {
  return (
    <div className="flex flex-col gap-1">
      <Label className="text-xs text-muted-foreground">{label}</Label>
      {children}
    </div>
  )
}

function toEditable(block: Block): EditableBlock {
  switch (block.kind) {
    case "exercise":
      return {
        kind: "exercise",
        name: block.name,
        prescription: block.prescription,
        restS: block.restS != null ? String(block.restS) : "",
        notes: block.notes ?? "",
      }
    case "group":
      return {
        kind: "group",
        label: block.label ?? "",
        rounds: block.rounds != null ? String(block.rounds) : "",
        items: block.items.map((i) => ({
          name: i.name,
          prescription: i.prescription,
          notes: i.notes ?? "",
        })),
      }
    case "freeform":
      return {
        kind: "freeform",
        textMd: block.textMd,
      }
  }
}

function toBlock(editable: EditableBlock): Block {
  switch (editable.kind) {
    case "exercise": {
      const out: ExerciseBlock = {
        kind: "exercise",
        name: editable.name,
        prescription: editable.prescription,
      }
      const restNumber = parseOptionalInt(editable.restS)
      if (restNumber != null) out.restS = restNumber
      if (editable.notes.trim() !== "") out.notes = editable.notes
      return out
    }
    case "group": {
      const out: GroupBlock = {
        kind: "group",
        items: editable.items.map((item) => toGroupItem(item)),
      }
      if (editable.label.trim() !== "") out.label = editable.label
      const rounds = parseOptionalInt(editable.rounds)
      if (rounds != null) out.rounds = rounds
      return out
    }
    case "freeform": {
      const out: FreeformBlock = {
        kind: "freeform",
        textMd: editable.textMd,
      }
      return out
    }
  }
}

function toGroupItem(item: EditableGroupItem): GroupItem {
  const out: GroupItem = {
    name: item.name,
    prescription: item.prescription,
  }
  if (item.notes.trim() !== "") out.notes = item.notes
  return out
}

function parseOptionalInt(value: string): number | null {
  const trimmed = value.trim()
  if (trimmed === "") return null
  const parsed = Number.parseInt(trimmed, 10)
  return Number.isNaN(parsed) ? null : parsed
}

function collectErrorMessages(errors: Record<string, unknown>): string[] {
  const messages: string[] = []
  for (const value of Object.values(errors)) {
    if (Array.isArray(value)) {
      for (const v of value) {
        if (typeof v === "string") messages.push(v)
      }
    } else if (typeof value === "string") {
      messages.push(value)
    }
  }
  return messages
}

function blocksEqual(a: EditableBlock[], b: EditableBlock[]): boolean {
  if (a.length !== b.length) return false
  return a.every((block, i) => editableBlockEqual(block, b[i]))
}

function editableBlockEqual(a: EditableBlock, b: EditableBlock): boolean {
  if (a.kind !== b.kind) return false
  switch (a.kind) {
    case "exercise": {
      const other = b as EditableExercise
      return (
        a.name === other.name &&
        a.prescription === other.prescription &&
        a.restS === other.restS &&
        a.notes === other.notes
      )
    }
    case "group": {
      const other = b as EditableGroup
      if (a.label !== other.label) return false
      if (a.rounds !== other.rounds) return false
      if (a.items.length !== other.items.length) return false
      return a.items.every((item, i) => {
        const oi = other.items[i]
        return (
          item.name === oi.name &&
          item.prescription === oi.prescription &&
          item.notes === oi.notes
        )
      })
    }
    case "freeform": {
      const other = b as EditableFreeform
      return a.textMd === other.textMd
    }
  }
}
