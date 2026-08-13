// Pure block-editing core: the editable mirror of a persisted Block, the
// conversions between the two, and the value helpers they need. No React, no
// Inertia — every editing surface (the inline workout editor, the live board's
// single-block sheet) builds on this.
//
// Editable blocks hold every field as a string so an input can be emptied
// without the value collapsing to a number or disappearing; `toBlock` is what
// re-narrows them for the wire.

import type {
  Block,
  ExerciseBlock,
  FreeformBlock,
  GroupBlock,
  GroupItem,
} from "@/lib/blocks"

export type {
  Block,
  ExerciseBlock,
  ExerciseMediaItem,
  FreeformBlock,
  GroupBlock,
  GroupItem,
} from "@/lib/blocks"

export type EditableExercise = {
  kind: "exercise"
  name: string
  prescription: string
  restS: string
  notes: string
}

export type EditableGroupItem = {
  name: string
  prescription: string
  notes: string
}

export type EditableGroup = {
  kind: "group"
  label: string
  rounds: string
  items: EditableGroupItem[]
}

export type EditableFreeform = {
  kind: "freeform"
  textMd: string
}

export type EditableBlock = EditableExercise | EditableGroup | EditableFreeform

export function toEditable(block: Block): EditableBlock {
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

export function toBlock(editable: EditableBlock): Block {
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

export function toGroupItem(item: EditableGroupItem): GroupItem {
  const out: GroupItem = {
    name: item.name,
    prescription: item.prescription,
  }
  if (item.notes.trim() !== "") out.notes = item.notes
  return out
}

export function parseOptionalInt(value: string): number | null {
  const trimmed = value.trim()
  if (trimmed === "") return null
  const parsed = Number.parseInt(trimmed, 10)
  return Number.isNaN(parsed) ? null : parsed
}

export function newEditableExercise(): EditableExercise {
  return { kind: "exercise", name: "", prescription: "", restS: "", notes: "" }
}

export function newEditableGroupItem(): EditableGroupItem {
  return { name: "", prescription: "", notes: "" }
}

export function newEditableGroup(): EditableGroup {
  return {
    kind: "group",
    label: "",
    rounds: "",
    items: [newEditableGroupItem()],
  }
}

export function newEditableFreeform(): EditableFreeform {
  return { kind: "freeform", textMd: "" }
}

export function blocksEqual(a: EditableBlock[], b: EditableBlock[]): boolean {
  if (a.length !== b.length) return false
  return a.every((block, i) => editableBlockEqual(block, b[i]))
}

export function editableBlockEqual(a: EditableBlock, b: EditableBlock): boolean {
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
