import { Head, router } from "@inertiajs/react"
import { useEffect } from "react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { BrandLockup } from "@/components/brand"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

type Student = {
  id: string
  name: string
  primaryGoal: string | null
  weeklyFrequency: number | null
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
  version: {
    id: string
    printedAt: string | null
  }
  workouts: Workout[]
}

type Props = {
  student: Student
  periodization: Periodization
}

export default function PrintablePeriodization({
  student,
  periodization,
}: Props) {
  useEffect(() => {
    if (typeof window === "undefined") return
    const fonts = document.fonts
    const ready = fonts?.ready ?? Promise.resolve()
    ready.then(() => window.print()).catch(() => window.print())
  }, [])

  const isPrinted = periodization.version.printedAt !== null

  return (
    <>
      <Head title={`Imprimir — ${student.name}`} />
      {!isPrinted && (
        <div className="print:hidden mx-auto flex w-[210mm] items-center justify-end gap-2 px-[8mm] py-3">
          <Button
            type="button"
            onClick={() =>
              router.post(
                `/students/${student.id}/periodizations/${periodization.id}/versions/${periodization.version.id}/print_confirmation`,
              )
            }
          >
            Marcar como impresso
          </Button>
        </div>
      )}
      <article className="print-page mx-auto flex h-[297mm] w-[210mm] flex-col bg-white text-black">
        <div className="px-[8mm] pt-[8mm] pb-[4mm]">
          <PrintHeader
            student={student}
            periodization={periodization}
          />
        </div>
        <WorkoutsFull workouts={periodization.workouts} />
      </article>
    </>
  )
}

function WorkoutsFull({ workouts }: { workouts: Workout[] }) {
  if (workouts.length <= 4) {
    const splitIdx = Math.ceil(workouts.length / 2)
    const topHalf = workouts.slice(0, splitIdx)
    const bottomHalf = workouts.slice(splitIdx)

    return (
      <section className="print-workouts-full flex flex-1 flex-col overflow-hidden">
        <div className="workouts-half flex-1 overflow-hidden px-[8mm] pt-[4mm] pb-[4mm]">
          <WorkoutsMasonry workouts={topHalf} />
        </div>
        {bottomHalf.length > 0 && (
          <div className="workouts-half flex-1 overflow-hidden px-[8mm] pt-[4mm] pb-[8mm] border-t border-dashed border-neutral-400">
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

  return (
    <section className="print-workouts-full flex flex-1 flex-col overflow-hidden">
      {rows.map((row, i) => {
        const isLast = i === rows.length - 1
        return (
          <div
            key={i}
            className={cn(
              "workouts-row grid flex-1 grid-cols-2 gap-x-[4mm] overflow-hidden px-[8mm] pt-[4mm]",
              isLast ? "pb-[8mm]" : "pb-[4mm]",
              i !== 0 && "border-t border-dashed border-neutral-400",
            )}
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
  periodization,
}: {
  student: Student
  periodization: Periodization
}) {
  const dateLabel = formatStartedOn(periodization.startedOn)
  const demographics = [
    student.primaryGoal,
    student.weeklyFrequency != null
      ? `${student.weeklyFrequency}× por semana`
      : null,
  ].filter(Boolean) as string[]

  return (
    <header className="flex flex-col gap-1">
      <div className="flex items-center justify-between text-[8pt] text-neutral-600">
        <BrandLockup size="sm" className="h-[7mm] text-black" />
        <span className="print-started-on">
          Periodização iniciada em {dateLabel}
        </span>
      </div>
      <h1 className="text-[16pt] font-semibold leading-tight">{student.name}</h1>
      {demographics.length > 0 && (
        <p className="text-[9pt] text-neutral-700">{demographics.join(" · ")}</p>
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

function formatStartedOn(iso: string) {
  const parts = iso.split("-")
  if (parts.length !== 3) return iso
  const [year, month, day] = parts
  return `${day}/${month}/${year}`
}

