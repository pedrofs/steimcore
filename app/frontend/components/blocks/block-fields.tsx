// The per-kind field editors for a draft block, plus the shared field row and
// block controls. Presentational only — they render an EditableBlock and report
// changes upward; the draft state lives in useBlocksDraft. Shared so the inline
// workout editor and the live board's single-block sheet edit the same fields.

import { ArrowDownIcon, ArrowUpIcon, PlusIcon, XIcon } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import type {
  EditableBlock,
  EditableExercise,
  EditableFreeform,
  EditableGroup,
  EditableGroupItem,
} from "@/lib/blocks-draft"

export const BLOCK_KIND_LABELS: Record<EditableBlock["kind"], string> = {
  exercise: "Exercício",
  group: "Grupo",
  freeform: "Texto livre",
}

export function FieldRow({
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

export function BlockControls({
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

export function ExerciseBlockFields({
  block,
  onChange,
}: {
  block: EditableExercise
  onChange: (partial: Partial<EditableExercise>) => void
}) {
  return (
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
  )
}

export function GroupBlockFields({
  block,
  onChange,
  onItemChange,
  onItemAppend,
  onItemRemove,
  onItemMoveUp,
  onItemMoveDown,
}: {
  block: EditableGroup
  onChange: (partial: Partial<EditableGroup>) => void
  onItemChange: (itemIndex: number, partial: Partial<EditableGroupItem>) => void
  onItemAppend: () => void
  onItemRemove: (itemIndex: number) => void
  onItemMoveUp: (itemIndex: number) => void
  onItemMoveDown: (itemIndex: number) => void
}) {
  const itemCount = block.items.length
  return (
    <>
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
    </>
  )
}

export function FreeformBlockFields({
  block,
  onChange,
}: {
  block: EditableFreeform
  onChange: (partial: Partial<EditableFreeform>) => void
}) {
  return (
    <Textarea
      value={block.textMd}
      onChange={(e) => onChange({ textMd: e.target.value })}
      rows={5}
      className="min-h-24 font-mono text-sm"
    />
  )
}
