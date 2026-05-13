import { Form, Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"

type Student = {
  id: string
  name: string
  age: number | null
  sex: string | null
  primaryGoal: string | null
  restrictionsSummary: string | null
  weeklyFrequency: number | null
  phone: string | null
  email: string | null
  anamnesisMd: string
  notesMd: string
  archived: boolean
}

type Props = {
  student: Student
}

export default function Edit({ student }: Props) {
  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Edite os dados estruturados e os textos livres do aluno.
        </p>
      </PageHeader>

      <Form
        method="patch"
        action={`/students/${student.id}`}
        className="flex flex-col gap-6"
      >
        {({ errors, processing }) => (
          <>
            <div className="flex flex-col gap-2">
              <Label htmlFor="name">Nome</Label>
              <Input
                id="name"
                name="student[name]"
                defaultValue={student.name}
                required
                className="h-11"
              />
              {errors.name && (
                <p className="text-sm text-destructive">
                  {errors.name.join(", ")}
                </p>
              )}
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="age">Idade</Label>
                <Input
                  id="age"
                  name="student[age]"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  defaultValue={student.age ?? ""}
                  className="h-11"
                />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="sex">Sexo</Label>
                <Input
                  id="sex"
                  name="student[sex]"
                  defaultValue={student.sex ?? ""}
                  className="h-11"
                  placeholder="Feminino, Masculino, Outro..."
                />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="primary_goal">Objetivo principal</Label>
                <Input
                  id="primary_goal"
                  name="student[primary_goal]"
                  defaultValue={student.primaryGoal ?? ""}
                  className="h-11"
                  placeholder="Hipertrofia, emagrecimento..."
                />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="weekly_frequency">
                  Frequência semanal
                </Label>
                <Input
                  id="weekly_frequency"
                  name="student[weekly_frequency]"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  max={7}
                  defaultValue={student.weeklyFrequency ?? ""}
                  className="h-11"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="phone">Telefone</Label>
                <Input
                  id="phone"
                  name="student[phone]"
                  type="tel"
                  inputMode="tel"
                  autoComplete="tel"
                  defaultValue={student.phone ?? ""}
                  className="h-11"
                  placeholder="(11) 99999-0000"
                />
                {errors.phone && (
                  <p className="text-sm text-destructive">
                    {errors.phone.join(", ")}
                  </p>
                )}
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="email">E-mail</Label>
                <Input
                  id="email"
                  name="student[email]"
                  type="email"
                  inputMode="email"
                  autoComplete="email"
                  defaultValue={student.email ?? ""}
                  className="h-11"
                  placeholder="aluno@exemplo.com"
                />
                {errors.email && (
                  <p className="text-sm text-destructive">
                    {errors.email.join(", ")}
                  </p>
                )}
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <Label htmlFor="restrictions_summary">Restrições</Label>
              <Textarea
                id="restrictions_summary"
                name="student[restrictions_summary]"
                defaultValue={student.restrictionsSummary ?? ""}
                rows={3}
                placeholder="Ex.: lombar sensível, ombro direito, joelho..."
              />
            </div>

            <div className="flex flex-col gap-2">
              <Label htmlFor="anamnesis_md">Anamnese (markdown)</Label>
              <Textarea
                id="anamnesis_md"
                name="student[anamnesis_md]"
                defaultValue={student.anamnesisMd}
                rows={10}
                className="min-h-48 font-mono text-sm"
                placeholder="## Histórico&#10;## Restrições&#10;## Objetivos"
              />
            </div>

            <div className="flex flex-col gap-2">
              <Label htmlFor="notes_md">Observações (markdown)</Label>
              <Textarea
                id="notes_md"
                name="student[notes_md]"
                defaultValue={student.notesMd}
                rows={6}
                className="min-h-32 font-mono text-sm"
                placeholder="Notas livres do treinador..."
              />
            </div>

            <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
              <Button asChild variant="outline" className="h-11 sm:h-10">
                <Link href={`/students/${student.id}`}>Cancelar</Link>
              </Button>
              <Button
                type="submit"
                disabled={processing}
                className="h-11 sm:h-10"
              >
                {processing ? "Salvando..." : "Salvar"}
              </Button>
            </div>
          </>
        )}
      </Form>
    </>
  )
}
