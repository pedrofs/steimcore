import { router } from "@inertiajs/react"
import {
  ChevronDownIcon,
  ChevronRightIcon,
  PencilIcon,
  WandSparklesIcon,
} from "lucide-react"
import { useEffect, useRef, useState } from "react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent } from "@/components/ui/tabs"
import { WorkoutEditor } from "@/components/workout-editor"
import { WorkoutsTabsList } from "@/components/workouts-tabs-list"

export type PeriodizationVersionWorkout = {
  id: string
  name: string
  position: number
  blocks: Block[]
}

export type PeriodizationVersionData = {
  id: string
  status: "pending" | "generating" | "completed" | "failed"
  bodyMd: string
  errorMessage: string | null
  promoted: boolean
  readOnly: boolean
  periodizationId: string
  workouts: PeriodizationVersionWorkout[]
}

export type PeriodizationViewScope =
  | { kind: "periodization" }
  | { kind: "workout"; workoutId: string }

type EditingDirty = {
  editingWorkoutId: string | null
  dirty: boolean
}

export type PeriodizationViewPresentation = "page" | "drawer"

type Props = {
  version: PeriodizationVersionData
  scope?: PeriodizationViewScope
  /**
   * Selects how the body is mounted. The shared component renders the same
   * affordances either way; the prop only controls minor presentation
   * details (e.g. dropping the section heading inside the drawer, where the
   * sheet header already names the artifact).
   */
  presentation?: PeriodizationViewPresentation
  editingDisabled?: boolean
  returnTo?: string
  /**
   * Reports the dirty state of the inline workout editor so the surrounding
   * surface (page action footer, drawer footer) can gate destructive actions
   * like "Salvar como ativa" with a discard-confirm.
   */
  onDirtyWorkoutChange?: (dirtyWorkoutName: string | null) => void
}

export function PeriodizationVersionView({
  version,
  scope = { kind: "periodization" },
  presentation = "page",
  editingDisabled = false,
  returnTo,
  onDirtyWorkoutChange,
}: Props) {
  const [{ editingWorkoutId, dirty }, setEditingState] = useState<EditingDirty>(
    { editingWorkoutId: null, dirty: false },
  )

  const workouts =
    scope.kind === "workout"
      ? version.workouts.filter((w) => w.id === scope.workoutId)
      : version.workouts

  if (scope.kind === "workout" && workouts.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">
        Treino não encontrado nesta versão.
      </p>
    )
  }

  const editingWorkout =
    editingWorkoutId != null
      ? workouts.find((w) => w.id === editingWorkoutId) ?? null
      : null
  const dirtyEditedWorkoutName =
    dirty && editingWorkout ? editingWorkout.name : null

  const dirtyCallbackRef = useRef(onDirtyWorkoutChange)
  dirtyCallbackRef.current = onDirtyWorkoutChange
  useEffect(() => {
    dirtyCallbackRef.current?.(dirtyEditedWorkoutName)
  }, [dirtyEditedWorkoutName])
  useEffect(() => () => dirtyCallbackRef.current?.(null), [])

  const discardLocalEdits = () =>
    setEditingState({ editingWorkoutId: null, dirty: false })

  const guardVoiceTrigger = (action: () => void) => {
    if (dirtyEditedWorkoutName) {
      if (
        !window.confirm(
          `Você tem alterações não salvas em ${dirtyEditedWorkoutName}. Descartar?`,
        )
      )
        return
      discardLocalEdits()
    }
    action()
  }

  const canEditPlan = !version.readOnly && !editingDisabled

  return (
    <div className="flex flex-col gap-6">
      {scope.kind === "periodization" && (
        <PlanSection
          bodyMd={version.bodyMd}
          editable={canEditPlan}
          onEditPlan={() =>
            guardVoiceTrigger(() =>
              router.post(`/periodization_versions/${version.id}/edit`),
            )
          }
        />
      )}

      <WorkoutsTabs
        version={version}
        workouts={workouts}
        showHeading={
          scope.kind === "periodization" && presentation === "page"
        }
        editingWorkoutId={editingWorkoutId}
        onEdit={(id) =>
          setEditingState({ editingWorkoutId: id, dirty: false })
        }
        onCancelEdit={() =>
          setEditingState({ editingWorkoutId: null, dirty: false })
        }
        onSaved={() =>
          setEditingState({ editingWorkoutId: null, dirty: false })
        }
        onDirtyChange={(d) =>
          setEditingState((prev) => ({ ...prev, dirty: d }))
        }
        dirtyEditedWorkoutName={dirtyEditedWorkoutName}
        onDiscardLocalEdits={discardLocalEdits}
        editingDisabled={editingDisabled}
        guardVoiceTrigger={guardVoiceTrigger}
        returnTo={returnTo}
      />
    </div>
  )
}

function PlanSection({
  bodyMd,
  editable,
  onEditPlan,
}: {
  bodyMd: string
  editable: boolean
  onEditPlan: () => void
}) {
  const [expanded, setExpanded] = useState(false)

  return (
    <section className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <button
          type="button"
          aria-expanded={expanded}
          onClick={() => setExpanded((v) => !v)}
          className="-mx-1 inline-flex items-center gap-1.5 rounded-md px-1 py-0.5 text-lg font-medium hover:bg-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          {expanded ? (
            <ChevronDownIcon className="size-4 text-muted-foreground" />
          ) : (
            <ChevronRightIcon className="size-4 text-muted-foreground" />
          )}
          Plano
        </button>
        {editable && (
          <AiButton onClick={onEditPlan}>Editar periodização</AiButton>
        )}
      </div>
      {expanded && (
        <Markdown content={bodyMd} placeholder="Plano sem conteúdo." />
      )}
    </section>
  )
}

function AiButton({
  onClick,
  disabled,
  children,
  fullWidthOnMobile = false,
}: {
  onClick: () => void
  disabled?: boolean
  children: React.ReactNode
  fullWidthOnMobile?: boolean
}) {
  return (
    <Button
      type="button"
      variant="outline"
      disabled={disabled}
      onClick={onClick}
      className={
        "h-11 gap-2 sm:h-10 " +
        (fullWidthOnMobile ? "w-full sm:w-auto " : "")
      }
    >
      <WandSparklesIcon className="size-4" />
      <span>{children}</span>
      <IaPill />
    </Button>
  )
}

function IaPill() {
  return (
    <span className="ml-1 rounded-full border border-foreground/15 bg-foreground/5 px-1.5 py-px text-[10px] font-semibold uppercase tracking-[0.12em] text-foreground/70">
      IA
    </span>
  )
}

function WorkoutsTabs({
  version,
  workouts,
  showHeading,
  editingWorkoutId,
  onEdit,
  onCancelEdit,
  onSaved,
  onDirtyChange,
  dirtyEditedWorkoutName,
  onDiscardLocalEdits,
  editingDisabled,
  guardVoiceTrigger,
  returnTo,
}: {
  version: PeriodizationVersionData
  workouts: PeriodizationVersionWorkout[]
  showHeading: boolean
  editingWorkoutId: string | null
  onEdit: (id: string) => void
  onCancelEdit: () => void
  onSaved: () => void
  onDirtyChange: (dirty: boolean) => void
  dirtyEditedWorkoutName: string | null
  onDiscardLocalEdits: () => void
  editingDisabled: boolean
  guardVoiceTrigger: (action: () => void) => void
  returnTo?: string
}) {
  const [activeTab, setActiveTab] = useState<string | undefined>(
    workouts[0]?.id,
  )

  if (workouts.length === 0) {
    return (
      <section className="flex flex-col gap-3">
        {showHeading && <h2 className="text-lg font-medium">Treinos</h2>}
        <p className="text-sm text-muted-foreground">
          Nenhum treino registrado.
        </p>
      </section>
    )
  }

  const someoneEditing = editingWorkoutId != null
  const showEditControls =
    !version.readOnly && !someoneEditing && !editingDisabled

  const handleTabChange = (next: string) => {
    if (next === activeTab) return
    if (dirtyEditedWorkoutName) {
      if (
        !window.confirm(
          `Você tem alterações não salvas em ${dirtyEditedWorkoutName}. Descartar?`,
        )
      ) {
        return
      }
      onDiscardLocalEdits()
    }
    setActiveTab(next)
  }

  const singleWorkout = workouts.length === 1

  return (
    <section className="flex flex-col gap-3">
      {showHeading && <h2 className="text-lg font-medium">Treinos</h2>}
      <Tabs
        value={singleWorkout ? workouts[0].id : activeTab}
        onValueChange={singleWorkout ? undefined : handleTabChange}
      >
        {!singleWorkout && <WorkoutsTabsList workouts={workouts} />}
        {workouts.map((w) => (
          <TabsContent key={w.id} value={w.id} className="flex flex-col gap-3">
            {editingWorkoutId === w.id ? (
              <WorkoutEditor
                versionId={version.id}
                workoutId={w.id}
                blocks={w.blocks}
                returnTo={returnTo}
                onCancel={onCancelEdit}
                onSaved={onSaved}
                onDirtyChange={onDirtyChange}
              />
            ) : (
              <>
                <BlocksRenderer
                  blocks={w.blocks}
                  emptyPlaceholder="Treino sem conteúdo."
                />
                {showEditControls && (
                  <div className="mt-1 flex flex-col gap-2 sm:flex-row sm:justify-end">
                    <AiButton
                      fullWidthOnMobile
                      onClick={() =>
                        guardVoiceTrigger(() =>
                          router.post(
                            `/periodization_versions/${version.id}/workouts/${w.id}/edit`,
                          ),
                        )
                      }
                    >
                      Editar treino
                    </AiButton>
                    <Button
                      type="button"
                      variant="outline"
                      className="h-11 w-full gap-2 sm:h-10 sm:w-auto"
                      onClick={() => onEdit(w.id)}
                    >
                      <PencilIcon className="size-4" />
                      Editar manualmente
                    </Button>
                  </div>
                )}
              </>
            )}
          </TabsContent>
        ))}
      </Tabs>
    </section>
  )
}
