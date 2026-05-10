import { Head } from "@inertiajs/react"
import { useEffect } from "react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"

type Student = {
  id: string
  name: string
  age: number | null
  sex: string | null
  primaryGoal: string | null
  weeklyFrequency: number | null
  restrictionsSummary: string | null
}

type Workout = {
  id: string
  name: string
  position: number
  blocks: Block[]
}

type Periodization = {
  id: string
  startedOn: string
  bodyMd: string
  workouts: Workout[]
}

type Organization = { name: string }

type Props = {
  student: Student
  organization: Organization
  periodization: Periodization
}

const ATTENDANCE_ROWS = 30

export default function PrintablePeriodization({
  student,
  organization,
  periodization,
}: Props) {
  useEffect(() => {
    if (typeof window === "undefined") return
    const fonts = document.fonts
    const ready = fonts?.ready ?? Promise.resolve()
    ready.then(() => window.print()).catch(() => window.print())
  }, [])

  return (
    <>
      <Head title={`Imprimir — ${student.name}`} />
      <article className="print-page mx-auto flex w-[210mm] min-h-[297mm] flex-col bg-white text-black">
        <FrontFace
          student={student}
          organization={organization}
          periodization={periodization}
        />
        <AttendanceGrid rowCount={ATTENDANCE_ROWS} />
      </article>
    </>
  )
}

function FrontFace({
  student,
  organization,
  periodization,
}: {
  student: Student
  organization: Organization
  periodization: Periodization
}) {
  return (
    <section className="print-face print-front flex h-[297mm] flex-col">
      <div className="print-half print-half-top flex flex-1 basis-1/2 flex-col gap-3 overflow-hidden p-[10mm] border-b border-dashed border-neutral-400">
        <PrintHeader
          student={student}
          organization={organization}
          periodization={periodization}
        />
        <div className="print-body flex-1 overflow-hidden">
          <Markdown
            content={periodization.bodyMd}
            placeholder="Plano sem conteúdo."
            className="print-body-md text-[10pt] leading-snug"
          />
        </div>
      </div>
      <div className="print-half print-half-bottom flex flex-1 basis-1/2 flex-col gap-2 overflow-hidden p-[10mm]">
        <h2 className="text-[10pt] font-semibold uppercase tracking-wide text-neutral-700">
          Treinos
        </h2>
        <WorkoutsMasonry workouts={periodization.workouts} />
      </div>
    </section>
  )
}

function PrintHeader({
  student,
  organization,
  periodization,
}: {
  student: Student
  organization: Organization
  periodization: Periodization
}) {
  const dateLabel = formatStartedOn(periodization.startedOn)
  const demographics = [
    student.age != null ? `${student.age} anos` : null,
    formatSex(student.sex),
    student.primaryGoal,
    student.weeklyFrequency != null
      ? `${student.weeklyFrequency}× por semana`
      : null,
  ].filter(Boolean) as string[]

  return (
    <header className="flex flex-col gap-1">
      <div className="flex items-baseline justify-between text-[8pt] text-neutral-600">
        <span className="print-org">{organization.name}</span>
        <span className="print-started-on">
          Periodização iniciada em {dateLabel}
        </span>
      </div>
      <h1 className="text-[16pt] font-semibold leading-tight">{student.name}</h1>
      {demographics.length > 0 && (
        <p className="text-[9pt] text-neutral-700">{demographics.join(" · ")}</p>
      )}
      {student.restrictionsSummary && (
        <p className="print-restrictions mt-1 rounded border border-neutral-800 bg-neutral-100 px-2 py-1 text-[9pt] font-medium text-neutral-900">
          <span className="uppercase tracking-wide">Restrições:</span>{" "}
          {student.restrictionsSummary}
        </p>
      )}
    </header>
  )
}

function WorkoutsMasonry({ workouts }: { workouts: Workout[] }) {
  if (workouts.length === 0) {
    return (
      <p className="text-[9pt] text-neutral-600">Nenhum treino registrado.</p>
    )
  }
  return (
    <div className="workouts-masonry">
      {workouts.map((w) => (
        <article key={w.id} className="workout-card mb-2">
          <h3 className="workout-card-title mb-1 text-[10pt] font-semibold">
            {w.name}
          </h3>
          <BlocksRenderer blocks={w.blocks} />
        </article>
      ))}
    </div>
  )
}

function AttendanceGrid({ rowCount }: { rowCount: number }) {
  const rows = Array.from({ length: rowCount }, (_, i) => i)
  return (
    <section className="attendance-grid flex h-[297mm] flex-col gap-2 p-[10mm]">
      <h2 className="text-[10pt] font-semibold uppercase tracking-wide text-neutral-700">
        Registro de sessões
      </h2>
      <table className="w-full border-collapse text-[9pt]">
        <thead>
          <tr>
            <th className="border border-neutral-700 px-2 py-1 text-left font-semibold w-[22mm]">
              Data
            </th>
            <th className="border border-neutral-700 px-2 py-1 text-left font-semibold w-[24mm]">
              Treino
            </th>
            <th className="border border-neutral-700 px-2 py-1 text-left font-semibold">
              Observações
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map((i) => (
            <tr key={i}>
              <td className="border border-neutral-400 px-2 py-1 h-[7mm]"></td>
              <td className="border border-neutral-400 px-2 py-1"></td>
              <td className="border border-neutral-400 px-2 py-1"></td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}

function formatStartedOn(iso: string) {
  const parts = iso.split("-")
  if (parts.length !== 3) return iso
  const [year, month, day] = parts
  return `${day}/${month}/${year}`
}

function formatSex(sex: string | null): string | null {
  if (!sex) return null
  const upper = sex.toUpperCase()
  if (upper === "F") return "feminino"
  if (upper === "M") return "masculino"
  return sex
}
