// The live board's single-block editor: a bottom sheet holding the field
// editors for one block, sized like the board's other sheets so it stays usable
// one-handed on a phone. Editing is surgical — the sheet writes straight into
// the draft as the trainer types, and closing it stages nothing extra; the
// commit happens from the board's sticky bar.

import {
  BLOCK_KIND_LABELS,
  ExerciseBlockFields,
  FreeformBlockFields,
  GroupBlockFields,
} from "@/components/blocks/block-fields"
import { Button } from "@/components/ui/button"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import type { BlocksDraft } from "@/hooks/use-blocks-draft"
import type {
  EditableBlock,
  EditableExercise,
  EditableFreeform,
  EditableGroup,
} from "@/lib/blocks-draft"

export function BlockEditSheet({
  open,
  onOpenChange,
  block,
  index,
  draft,
}: {
  open: boolean
  onOpenChange: (next: boolean) => void
  block: EditableBlock
  index: number
  draft: BlocksDraft
}) {
  const onChange = (partial: Partial<EditableBlock>) =>
    draft.updateBlock(index, partial)

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="bottom"
        className="max-h-[min(85vh,calc(100dvh-var(--keyboard-h,0px)-env(safe-area-inset-top)-1rem))] overflow-y-auto"
      >
        <SheetHeader>
          <SheetTitle>Editar {BLOCK_KIND_LABELS[block.kind].toLowerCase()}</SheetTitle>
        </SheetHeader>
        <div className="flex flex-col gap-3 p-4 pt-0">
          {block.kind === "exercise" && (
            <ExerciseBlockFields
              block={block}
              onChange={onChange as (partial: Partial<EditableExercise>) => void}
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
            />
          )}
          {block.kind === "freeform" && (
            <FreeformBlockFields
              block={block}
              onChange={onChange as (partial: Partial<EditableFreeform>) => void}
            />
          )}
          <Button type="button" className="h-11" onClick={() => onOpenChange(false)}>
            Concluir
          </Button>
        </div>
      </SheetContent>
    </Sheet>
  )
}
