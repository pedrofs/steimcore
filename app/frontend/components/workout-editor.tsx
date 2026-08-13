import { useForm } from "@inertiajs/react"
import { PlusIcon } from "lucide-react"
import { useEffect, useRef } from "react"

import {
  BLOCK_KIND_LABELS,
  BlockControls,
  ExerciseBlockFields,
  FreeformBlockFields,
  GroupBlockFields,
} from "@/components/blocks/block-fields"
import { Button } from "@/components/ui/button"
import { useBlocksDraft, type BlocksDraft } from "@/hooks/use-blocks-draft"
import type {
  Block,
  EditableBlock,
  EditableExercise,
  EditableFreeform,
  EditableGroup,
} from "@/lib/blocks-draft"
import type { ExerciseSuggestion } from "@/lib/exercise-suggestions"
import { cn } from "@/lib/utils"

type Props = {
  /** PATCH endpoint for this workout's blocks. Lets the same editor target a
   *  live-plan version workout or a template workout (PRD #170). */
  action: string
  blocks: Block[]
  onCancel: () => void
  onSaved: () => void
  onDirtyChange?: (dirty: boolean) => void
  returnTo?: string
  /** The **Exercise suggestion** corpus for the name fields. Optional: a
   *  surface that does not ship it still edits, just without autocomplete. */
  suggestions?: ExerciseSuggestion[]
}

export function WorkoutEditor({
  action,
  blocks,
  onCancel,
  onSaved,
  onDirtyChange,
  returnTo,
  suggestions,
}: Props) {
  const draft = useBlocksDraft(blocks)
  // Inertia owns submission only — the draft blocks live in the hook, and
  // `transform` swaps the whole payload in at submit time.
  const { patch, errors, transform, processing } = useForm<{ blocks: EditableBlock[] }>({
    blocks: [],
  })

  const errorMessages = collectErrorMessages(errors)

  const onDirtyChangeRef = useRef(onDirtyChange)
  onDirtyChangeRef.current = onDirtyChange

  useEffect(() => {
    onDirtyChangeRef.current?.(draft.dirty)
  }, [draft.dirty])

  useEffect(() => {
    return () => {
      onDirtyChangeRef.current?.(false)
    }
  }, [])

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    transform(() => {
      const payload: Record<string, unknown> = {
        workout: { blocks: draft.payload().blocks },
      }
      if (returnTo) payload.return_to = returnTo
      return payload
    })
    patch(action, {
      preserveScroll: true,
      onSuccess: onSaved,
    })
  }

  const blockCount = draft.blocks.length

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
        {draft.blocks.map((block, index) => (
          <BlockEditorCard
            key={index}
            block={block}
            index={index}
            isFirst={index === 0}
            isLast={index === blockCount - 1}
            draft={draft}
            suggestions={suggestions}
          />
        ))}
      </div>

      <AddBlockButtons
        onAddExercise={draft.appendExercise}
        onAddGroup={draft.appendGroup}
        onAddFreeform={draft.appendFreeform}
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

const CARD_BACKGROUNDS: Record<EditableBlock["kind"], string> = {
  exercise: "bg-background",
  group: "bg-muted/20",
  freeform: "bg-background",
}

function BlockEditorCard({
  block,
  index,
  isFirst,
  isLast,
  draft,
  suggestions,
}: {
  block: EditableBlock
  index: number
  isFirst: boolean
  isLast: boolean
  draft: BlocksDraft
  suggestions?: ExerciseSuggestion[]
}) {
  const onChange = (partial: Partial<EditableBlock>) =>
    draft.updateBlock(index, partial)

  return (
    <div className={cn("rounded-lg border p-3", CARD_BACKGROUNDS[block.kind])}>
      <div className="mb-2 flex items-center justify-between gap-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {BLOCK_KIND_LABELS[block.kind]}
        </p>
        <BlockControls
          isFirst={isFirst}
          isLast={isLast}
          onMoveUp={() => draft.moveBlock(index, -1)}
          onMoveDown={() => draft.moveBlock(index, 1)}
          onRemove={() => draft.removeBlock(index)}
        />
      </div>
      {block.kind === "exercise" && (
        <ExerciseBlockFields
          block={block}
          onChange={onChange as (partial: Partial<EditableExercise>) => void}
          suggestions={suggestions}
        />
      )}
      {block.kind === "group" && (
        <GroupBlockFields
          block={block}
          onChange={onChange as (partial: Partial<EditableGroup>) => void}
          onItemChange={(itemIndex, partial) =>
            draft.updateGroupItem(index, itemIndex, partial)
          }
          onItemAppend={() => draft.appendGroupItem(index)}
          onItemRemove={(itemIndex) => draft.removeGroupItem(index, itemIndex)}
          onItemMoveUp={(itemIndex) => draft.moveGroupItem(index, itemIndex, -1)}
          onItemMoveDown={(itemIndex) => draft.moveGroupItem(index, itemIndex, 1)}
          suggestions={suggestions}
        />
      )}
      {block.kind === "freeform" && (
        <FreeformBlockFields
          block={block}
          onChange={onChange as (partial: Partial<EditableFreeform>) => void}
        />
      )}
    </div>
  )
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
