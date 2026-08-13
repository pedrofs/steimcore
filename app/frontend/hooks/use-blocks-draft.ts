// Headless state for editing a Workout's blocks. Owns the editable blocks
// array, every operation on it, dirty tracking, and the payload builder — but
// no submission: the caller decides where and how the payload is sent, so the
// same hook serves the inline editor (full-form, PATCH to the version or
// template workout endpoint) and the live board's single-block sheet.

import { useCallback, useMemo, useRef, useState } from "react"

import {
  type Block,
  type EditableBlock,
  type EditableGroup,
  type EditableGroupItem,
  blocksEqual,
  newEditableExercise,
  newEditableFreeform,
  newEditableGroup,
  newEditableGroupItem,
  toBlock,
  toEditable,
} from "@/lib/blocks-draft"

// Where a draft block came from in the blocks array it was seeded with — null
// for a block the trainer just added. Submitted alongside the blocks so the
// server can remap a live session's completed-block indices onto the new array.
export type OriginIndex = number | null

export type BlocksDraftPayload = {
  blocks: Block[]
  originIndices: OriginIndex[]
}

export type BlocksDraft = {
  blocks: EditableBlock[]
  originIndices: OriginIndex[]
  dirty: boolean
  updateBlock: (index: number, partial: Partial<EditableBlock>) => void
  removeBlock: (index: number) => void
  moveBlock: (index: number, direction: -1 | 1) => void
  appendExercise: () => void
  appendGroup: () => void
  appendFreeform: () => void
  updateGroupItem: (
    blockIndex: number,
    itemIndex: number,
    partial: Partial<EditableGroupItem>,
  ) => void
  appendGroupItem: (blockIndex: number) => void
  removeGroupItem: (blockIndex: number, itemIndex: number) => void
  moveGroupItem: (
    blockIndex: number,
    itemIndex: number,
    direction: -1 | 1,
  ) => void
  reset: () => void
  payload: () => BlocksDraftPayload
}

type Entry = {
  block: EditableBlock
  origin: OriginIndex
}

function seed(blocks: Block[]): Entry[] {
  return blocks.map((block, index) => ({ block: toEditable(block), origin: index }))
}

export function useBlocksDraft(blocks: Block[]): BlocksDraft {
  const initial = useMemo(() => seed(blocks), [blocks])
  const [entries, setEntries] = useState<Entry[]>(initial)

  // Kept in a ref so `payload()` and the operations never have to be rebuilt
  // when the draft changes — callers can hand them straight to child props.
  const entriesRef = useRef(entries)
  entriesRef.current = entries

  const update = useCallback((fn: (current: Entry[]) => Entry[]) => {
    setEntries((current) => fn(current))
  }, [])

  const updateBlock = useCallback(
    (index: number, partial: Partial<EditableBlock>) => {
      update((current) =>
        current.map((entry, i) =>
          i === index
            ? { ...entry, block: { ...entry.block, ...partial } as EditableBlock }
            : entry,
        ),
      )
    },
    [update],
  )

  const removeBlock = useCallback(
    (index: number) => {
      update((current) => current.filter((_, i) => i !== index))
    },
    [update],
  )

  const moveBlock = useCallback(
    (index: number, direction: -1 | 1) => {
      update((current) => {
        const target = index + direction
        if (target < 0 || target >= current.length) return current
        const next = [...current]
        ;[next[index], next[target]] = [next[target], next[index]]
        return next
      })
    },
    [update],
  )

  const append = useCallback(
    (block: EditableBlock) => {
      update((current) => [...current, { block, origin: null }])
    },
    [update],
  )

  const appendExercise = useCallback(() => append(newEditableExercise()), [append])
  const appendGroup = useCallback(() => append(newEditableGroup()), [append])
  const appendFreeform = useCallback(() => append(newEditableFreeform()), [append])

  const updateGroup = useCallback(
    (blockIndex: number, fn: (items: EditableGroupItem[]) => EditableGroupItem[]) => {
      update((current) =>
        current.map((entry, i) => {
          if (i !== blockIndex || entry.block.kind !== "group") return entry
          const group: EditableGroup = { ...entry.block, items: fn(entry.block.items) }
          return { ...entry, block: group }
        }),
      )
    },
    [update],
  )

  const updateGroupItem = useCallback(
    (blockIndex: number, itemIndex: number, partial: Partial<EditableGroupItem>) => {
      updateGroup(blockIndex, (items) =>
        items.map((item, i) => (i === itemIndex ? { ...item, ...partial } : item)),
      )
    },
    [updateGroup],
  )

  const appendGroupItem = useCallback(
    (blockIndex: number) => {
      updateGroup(blockIndex, (items) => [...items, newEditableGroupItem()])
    },
    [updateGroup],
  )

  const removeGroupItem = useCallback(
    (blockIndex: number, itemIndex: number) => {
      updateGroup(blockIndex, (items) =>
        items.length <= 1 ? items : items.filter((_, i) => i !== itemIndex),
      )
    },
    [updateGroup],
  )

  const moveGroupItem = useCallback(
    (blockIndex: number, itemIndex: number, direction: -1 | 1) => {
      updateGroup(blockIndex, (items) => {
        const target = itemIndex + direction
        if (target < 0 || target >= items.length) return items
        const next = [...items]
        ;[next[itemIndex], next[target]] = [next[target], next[itemIndex]]
        return next
      })
    },
    [updateGroup],
  )

  const reset = useCallback(() => setEntries(initial), [initial])

  const payload = useCallback(
    () => ({
      blocks: entriesRef.current.map((entry) => toBlock(entry.block)),
      originIndices: entriesRef.current.map((entry) => entry.origin),
    }),
    [],
  )

  const draftBlocks = useMemo(() => entries.map((entry) => entry.block), [entries])
  const originIndices = useMemo(() => entries.map((entry) => entry.origin), [entries])

  const dirty = useMemo(
    () => !blocksEqual(draftBlocks, initial.map((entry) => entry.block)),
    [draftBlocks, initial],
  )

  return {
    blocks: draftBlocks,
    originIndices,
    dirty,
    updateBlock,
    removeBlock,
    moveBlock,
    appendExercise,
    appendGroup,
    appendFreeform,
    updateGroupItem,
    appendGroupItem,
    removeGroupItem,
    moveGroupItem,
    reset,
    payload,
  }
}
