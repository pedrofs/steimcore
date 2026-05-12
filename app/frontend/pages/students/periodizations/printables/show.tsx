import { Head } from "@inertiajs/react"
import { useEffect } from "react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { Markdown } from "@/components/markdown"
import { cn } from "@/lib/utils"

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
      <article className="print-page mx-auto flex w-[210mm] flex-col bg-white text-black">
        <PeriodizationHalf
          student={student}
          organization={organization}
          periodization={periodization}
        />
        <AttendanceHalf rowCount={ATTENDANCE_ROWS} />
        <WorkoutsFull workouts={periodization.workouts} />
      </article>
    </>
  )
}

function PeriodizationHalf({
  student,
  organization,
  periodization,
}: {
  student: Student
  organization: Organization
  periodization: Periodization
}) {
  return (
    <section className="print-half print-half-periodization flex h-[148.5mm] flex-col gap-1 overflow-hidden px-[8mm] pt-[8mm] pb-[4mm]">
      <PrintHeader
        student={student}
        organization={organization}
        periodization={periodization}
      />
      <div className="print-body flex-1 overflow-hidden">
        <Markdown
          content={periodization.bodyMd}
          placeholder="Plano sem conteúdo."
          className="print-body-md text-[8.5pt] leading-tight [&_h1]:hidden [&_h2]:text-[10pt] [&_h2]:font-semibold [&_h2]:mt-1.5 [&_h2]:mb-0.5 [&_h3]:text-[9pt] [&_h3]:font-semibold [&_h3]:mt-1 [&_h3]:mb-0 [&_p]:my-0.5 [&_p]:leading-tight [&_ul]:my-0.5 [&_ul]:pl-4 [&_ol]:my-0.5 [&_ol]:pl-4 [&_li]:my-0 [&_li]:leading-tight [&_li>p]:my-0 [&_strong]:font-semibold [&_hr]:my-1"
        />
      </div>
    </section>
  )
}

function WorkoutsFull({ workouts }: { workouts: Workout[] }) {
  if (workouts.length <= 4) {
    const splitIdx = Math.ceil(workouts.length / 2)
    const topHalf = workouts.slice(0, splitIdx)
    const bottomHalf = workouts.slice(splitIdx)

    return (
      <section className="print-workouts-full flex h-[297mm] flex-col break-before-page">
        <div className="workouts-half h-[148.5mm] overflow-hidden px-[8mm] pt-[8mm] pb-[4mm]">
          <WorkoutsMasonry workouts={topHalf} />
        </div>
        {bottomHalf.length > 0 && (
          <div className="workouts-half h-[148.5mm] overflow-hidden px-[8mm] pt-[4mm] pb-[8mm] border-t border-dashed border-neutral-400">
            <WorkoutsMasonry workouts={bottomHalf} />
          </div>
        )}
      </section>
    )
  }

  const rows: Workout[][] = []
  for (let i = 0; i < workouts.length; i += 2) {
    rows.push(workouts.slice(i, i + 2))
  }
  const rowHeightMm = 297 / rows.length

  return (
    <section className="print-workouts-full flex h-[297mm] flex-col break-before-page">
      {rows.map((row, i) => {
        const isFirst = i === 0
        const isLast = i === rows.length - 1
        return (
          <div
            key={i}
            className={cn(
              "workouts-row grid grid-cols-2 gap-x-[4mm] overflow-hidden px-[8mm]",
              isFirst ? "pt-[8mm]" : "pt-[4mm]",
              isLast ? "pb-[8mm]" : "pb-[4mm]",
              !isFirst && "border-t border-dashed border-neutral-400",
            )}
            style={{ height: `${rowHeightMm}mm` }}
          >
            {row.map((w) => (
              <WorkoutCard key={w.id} workout={w} />
            ))}
          </div>
        )
      })}
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
        <WorkoutCard key={w.id} workout={w} className="mb-1" />
      ))}
    </div>
  )
}

function WorkoutCard({
  workout,
  className,
}: {
  workout: Workout
  className?: string
}) {
  return (
    <article className={cn("workout-card overflow-hidden", className)}>
      <h3 className="workout-card-title text-[9pt] font-semibold leading-tight border-b border-neutral-400 pb-0.5 mb-0.5 truncate">
        {workout.name}
      </h3>
      <BlocksRenderer blocks={workout.blocks} dense />
    </article>
  )
}

function AttendanceHalf({ rowCount }: { rowCount: number }) {
  const rows = Array.from({ length: rowCount }, (_, i) => i)
  return (
    <section className="attendance-half flex h-[148.5mm] flex-col gap-1 overflow-hidden px-[8mm] pt-[4mm] pb-[8mm] border-t border-dashed border-neutral-400">
      <h2 className="text-[9pt] font-semibold uppercase tracking-wide text-neutral-700">
        Registro de sessões
      </h2>
      <div className="attendance-columns flex flex-1 gap-3">
        <AttendanceTable rows={rows} />
        <AttendanceTable rows={rows} />
      </div>
    </section>
  )
}

function AttendanceTable({ rows }: { rows: number[] }) {
  return (
    <table className="attendance-table flex-1 border-collapse text-[7.5pt]">
      <thead>
        <tr>
          <th className="border border-neutral-700 px-1 py-0.5 text-left font-semibold w-[18mm]">
            Data
          </th>
          <th className="border border-neutral-700 px-1 py-0.5 text-left font-semibold w-[16mm]">
            Treino
          </th>
          <th className="border border-neutral-700 px-1 py-0.5 text-left font-semibold">
            Observações
          </th>
        </tr>
      </thead>
      <tbody>
        {rows.map((i) => (
          <tr key={i}>
            <td className="border border-neutral-400 px-1 py-0 h-[3.7mm]"></td>
            <td className="border border-neutral-400 px-1 py-0"></td>
            <td className="border border-neutral-400 px-1 py-0"></td>
          </tr>
        ))}
      </tbody>
    </table>
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
