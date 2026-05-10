import { Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"

type Student = {
  id: string
  name: string
  age: number | null
  sex: string | null
  primaryGoal: string | null
  restrictionsSummary: string | null
  weeklyFrequency: number | null
  anamnesisMd: string
  notesMd: string
  archived: boolean
  activePeriodizationId: string | null
}

type Props = {
  student: Student
}

export default function Show({ student }: Props) {
  return (
    <>
      <PageHeader
        actions={
          <>
            <Button
              asChild
              variant="outline"
              className="h-11 w-full sm:h-10 sm:w-auto"
            >
              <Link href={`/students/${student.id}/voice_recordings/new`}>
                Gravar anamnese
              </Link>
            </Button>
            <Button
              asChild
              variant="outline"
              className="h-11 w-full sm:h-10 sm:w-auto"
            >
              <Link href={`/students/${student.id}/periodizations/new`}>
                Criar periodização
              </Link>
            </Button>
            <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
              <Link href={`/students/${student.id}/edit`}>Editar perfil</Link>
            </Button>
          </>
        }
      >
        {student.archived && (
          <span className="inline-flex w-fit items-center rounded-full border border-dashed bg-muted/40 px-2 py-0.5 text-xs text-muted-foreground">
            Arquivado
          </span>
        )}
      </PageHeader>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-medium">Dados estruturados</h2>
        <dl className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Field label="Idade" value={formatNumber(student.age)} />
          <Field label="Sexo" value={student.sex} />
          <Field label="Objetivo principal" value={student.primaryGoal} />
          <Field
            label="Frequência semanal"
            value={
              student.weeklyFrequency != null
                ? `${student.weeklyFrequency}x/semana`
                : null
            }
          />
          <Field
            label="Restrições"
            value={student.restrictionsSummary}
            className="sm:col-span-2"
          />
        </dl>
      </section>

      {student.activePeriodizationId && (
        <section className="flex flex-col gap-2">
          <h2 className="text-lg font-medium">Periodização ativa</h2>
          <Button
            asChild
            variant="outline"
            className="h-11 w-fit sm:h-10"
          >
            <Link
              href={`/students/${student.id}/periodizations/${student.activePeriodizationId}`}
            >
              Abrir periodização
            </Link>
          </Button>
        </section>
      )}

      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Anamnese</h2>
        <Markdown content={student.anamnesisMd} placeholder="Sem anamnese registrada ainda." />
      </section>

      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Observações</h2>
        <Markdown content={student.notesMd} placeholder="Sem observações." />
      </section>
    </>
  )
}

function Field({
  label,
  value,
  className,
}: {
  label: string
  value: string | null
  className?: string
}) {
  return (
    <div className={className}>
      <dt className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </dt>
      <dd className="mt-1 text-sm">
        {value && value.length > 0 ? value : (
          <span className="text-muted-foreground">—</span>
        )}
      </dd>
    </div>
  )
}

function Markdown({
  content,
  placeholder,
}: {
  content: string
  placeholder: string
}) {
  const trimmed = content.trim()
  if (trimmed.length === 0) {
    return (
      <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
        {placeholder}
      </p>
    )
  }
  return (
    <pre className="whitespace-pre-wrap rounded-xl border bg-muted/30 p-4 font-sans text-sm leading-relaxed">
      {content}
    </pre>
  )
}

function formatNumber(value: number | null): string | null {
  return value == null ? null : String(value)
}
