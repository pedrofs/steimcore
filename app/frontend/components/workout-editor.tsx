import { useForm } from "@inertiajs/react"

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
}

export function WorkoutEditor({ versionId, workoutId, blocks, onCancel, onSaved }: Props) {
  const form = useForm<{ blocks: EditableBlock[] }>({
    blocks: blocks.map(toEditable),
  })

  const errorMessages = collectErrorMessages(form.errors)

  const updateBlock = (index: number, partial: Partial<EditableBlock>) => {
    const next = form.data.blocks.map((b, i) =>
      i === index ? ({ ...b, ...partial } as EditableBlock) : b,
    )
    form.setData("blocks", next)
  }

  const updateGroupItem = (
    blockIndex: number,
    itemIndex: number,
    partial: Partial<EditableGroupItem>,
  ) => {
    const block = form.data.blocks[blockIndex]
    if (block.kind !== "group") return
    const nextItems = block.items.map((item, i) =>
      i === itemIndex ? { ...item, ...partial } : item,
    )
    updateBlock(blockIndex, { items: nextItems } as Partial<EditableGroup>)
  }

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form
      .transform((data) => ({ workout: { blocks: data.blocks.map(toBlock) } }))
      .patch(`/periodization_versions/${versionId}/workouts/${workoutId}`, {
        preserveScroll: true,
        onSuccess: onSaved,
      })
  }

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
        {form.data.blocks.map((block, index) => (
          <BlockEditor
            key={index}
            block={block}
            onChange={(partial) => updateBlock(index, partial)}
            onItemChange={(itemIndex, partial) =>
              updateGroupItem(index, itemIndex, partial)
            }
          />
        ))}
      </div>

      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button
          type="button"
          variant="outline"
          className="h-11 sm:h-10"
          onClick={onCancel}
        >
          Cancelar
        </Button>
        <Button type="submit" disabled={form.processing} className="h-11 sm:h-10">
          {form.processing ? "Salvando..." : "Salvar treino"}
        </Button>
      </div>
    </form>
  )
}

function BlockEditor({
  block,
  onChange,
  onItemChange,
}: {
  block: EditableBlock
  onChange: (partial: Partial<EditableBlock>) => void
  onItemChange: (itemIndex: number, partial: Partial<EditableGroupItem>) => void
}) {
  switch (block.kind) {
    case "exercise":
      return <ExerciseBlockEditor block={block} onChange={onChange} />
    case "group":
      return (
        <GroupBlockEditor
          block={block}
          onChange={onChange}
          onItemChange={onItemChange}
        />
      )
    case "freeform":
      return <FreeformBlockEditor block={block} onChange={onChange} />
  }
}

function ExerciseBlockEditor({
  block,
  onChange,
}: {
  block: EditableExercise
  onChange: (partial: Partial<EditableExercise>) => void
}) {
  return (
    <div className="rounded-lg border bg-background p-3">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Exercício
      </p>
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
}: {
  block: EditableGroup
  onChange: (partial: Partial<EditableGroup>) => void
  onItemChange: (itemIndex: number, partial: Partial<EditableGroupItem>) => void
}) {
  return (
    <div className="rounded-lg border bg-muted/20 p-3">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Grupo
      </p>
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
            <p className="mb-1 text-xs font-medium text-muted-foreground">
              Item {itemIndex + 1}
            </p>
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
      </div>
    </div>
  )
}

function FreeformBlockEditor({
  block,
  onChange,
}: {
  block: EditableFreeform
  onChange: (partial: Partial<EditableFreeform>) => void
}) {
  return (
    <div className="rounded-lg border bg-background p-3">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Texto livre
      </p>
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
