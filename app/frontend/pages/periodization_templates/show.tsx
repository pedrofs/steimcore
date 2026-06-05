import { router } from "@inertiajs/react"
import { ChevronDownIcon, ChevronRightIcon, Trash2Icon } from "lucide-react"
import { useState } from "react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent } from "@/components/ui/tabs"
import { WorkoutsTabsList } from "@/components/workouts-tabs-list"

type TemplateWorkout = {
  id: string
  name: string
  position: number
  blocks: Block[]
}

type Template = {
  id: string
  name: string
  description: string | null
  bodyMd: string
  workouts: TemplateWorkout[]
}

type Props = {
  template: Template
}

export default function Show({ template }: Props) {
  return (
    <>
      <PageHeader
        actions={
          <Button
            type="button"
            variant="outline"
            className="h-11 gap-2 sm:h-10"
            onClick={() => {
              if (confirm(`Excluir o modelo "${template.name}"?`)) {
                router.delete(`/periodization_templates/${template.id}`)
              }
            }}
          >
            <Trash2Icon className="size-4" />
            Excluir
          </Button>
        }
      >
        {template.description && (
          <p className="text-sm text-muted-foreground">
            {template.description}
          </p>
        )}
      </PageHeader>

      <div className="flex flex-col gap-6">
        <PlanSection bodyMd={template.bodyMd} />
        <WorkoutsTabs workouts={template.workouts} />
      </div>
    </>
  )
}

function PlanSection({ bodyMd }: { bodyMd: string }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <section className="flex flex-col gap-2">
      <button
        type="button"
        aria-expanded={expanded}
        onClick={() => setExpanded((v) => !v)}
        className="-mx-1 inline-flex w-fit items-center gap-1.5 rounded-md px-1 py-0.5 text-lg font-medium hover:bg-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        {expanded ? (
          <ChevronDownIcon className="size-4 text-muted-foreground" />
        ) : (
          <ChevronRightIcon className="size-4 text-muted-foreground" />
        )}
        Plano
      </button>
      {expanded && (
        <Markdown content={bodyMd} placeholder="Plano sem conteúdo." />
      )}
    </section>
  )
}

function WorkoutsTabs({ workouts }: { workouts: TemplateWorkout[] }) {
  const [activeTab, setActiveTab] = useState<string | undefined>(workouts[0]?.id)

  if (workouts.length === 0) {
    return (
      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-medium">Treinos</h2>
        <p className="text-sm text-muted-foreground">
          Nenhum treino registrado.
        </p>
      </section>
    )
  }

  const singleWorkout = workouts.length === 1

  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Treinos</h2>
      <Tabs
        value={singleWorkout ? workouts[0].id : activeTab}
        onValueChange={singleWorkout ? undefined : setActiveTab}
      >
        {!singleWorkout && <WorkoutsTabsList workouts={workouts} />}
        {workouts.map((w) => (
          <TabsContent key={w.id} value={w.id} className="flex flex-col gap-3">
            <BlocksRenderer
              blocks={w.blocks}
              emptyPlaceholder="Treino sem conteúdo."
            />
          </TabsContent>
        ))}
      </Tabs>
    </section>
  )
}
