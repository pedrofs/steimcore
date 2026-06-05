import { Form, Link } from "@inertiajs/react"
import { PencilIcon } from "lucide-react"
import { useState } from "react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { PageHeader } from "@/components/page-header"
import { WorkoutEditor } from "@/components/workout-editor"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tabs, TabsContent } from "@/components/ui/tabs"
import { Textarea } from "@/components/ui/textarea"
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

export default function Edit({ template }: Props) {
  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Edite o modelo no lugar — nome, descrição e treinos. As alterações não
          criam versões nem histórico.
        </p>
      </PageHeader>

      <div className="flex flex-col gap-8">
        <DetailsForm template={template} />
        <WorkoutsSection template={template} />
      </div>
    </>
  )
}

function DetailsForm({ template }: { template: Template }) {
  return (
    <Form
      method="patch"
      action={`/periodization_templates/${template.id}`}
      className="flex flex-col gap-4"
    >
      {({ errors, processing }) => (
        <>
          <div className="flex flex-col gap-2">
            <Label htmlFor="name">Nome</Label>
            <Input
              id="name"
              name="periodization_template[name]"
              defaultValue={template.name}
              required
              className="h-11"
            />
            {errors.name && (
              <p className="text-sm text-destructive">
                {errors.name.join(", ")}
              </p>
            )}
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="description">Descrição</Label>
            <Textarea
              id="description"
              name="periodization_template[description]"
              defaultValue={template.description ?? ""}
              rows={3}
              className="min-h-20"
              placeholder="ex.: Iniciante 3x/semana, foco hipertrofia"
            />
            {errors.description && (
              <p className="text-sm text-destructive">
                {errors.description.join(", ")}
              </p>
            )}
          </div>

          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button asChild variant="outline" className="h-11 sm:h-10">
              <Link href={`/periodization_templates/${template.id}`}>
                Concluir
              </Link>
            </Button>
            <Button
              type="submit"
              disabled={processing}
              className="h-11 sm:h-10"
            >
              {processing ? "Salvando..." : "Salvar dados"}
            </Button>
          </div>
        </>
      )}
    </Form>
  )
}

function WorkoutsSection({ template }: { template: Template }) {
  const { workouts } = template
  const [activeTab, setActiveTab] = useState<string | undefined>(
    workouts[0]?.id,
  )

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
            <WorkoutTabContent template={template} workout={w} />
          </TabsContent>
        ))}
      </Tabs>
    </section>
  )
}

function WorkoutTabContent({
  template,
  workout,
}: {
  template: Template
  workout: TemplateWorkout
}) {
  const [editing, setEditing] = useState(false)

  if (editing) {
    return (
      <WorkoutEditor
        action={`/periodization_templates/${template.id}/workouts/${workout.id}`}
        blocks={workout.blocks}
        onCancel={() => setEditing(false)}
        onSaved={() => setEditing(false)}
      />
    )
  }

  return (
    <>
      <div className="flex justify-end">
        <Button
          type="button"
          variant="outline"
          className="h-11 gap-2 sm:h-10"
          onClick={() => setEditing(true)}
        >
          <PencilIcon className="size-4" />
          Editar treino
        </Button>
      </div>
      <BlocksRenderer
        blocks={workout.blocks}
        emptyPlaceholder="Treino sem conteúdo."
      />
    </>
  )
}
