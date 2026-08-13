import { Link } from "@inertiajs/react"
import { motion } from "motion/react"

import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { cn } from "@/lib/utils"

type WorkoutSummary = {
  id: string
  name: string
  position: number
}

type PeriodizationProgress = {
  target: number
  sessionsDone: number
  sessionsRemaining: number
  overdue: boolean
  due: boolean
}

type PeriodizationSummary = {
  id: string
  ordinal: number
  archived: boolean
  startedOn: string
  endedOn: string | null
  lengthWeeks: number | null
  workouts: WorkoutSummary[]
  progress: PeriodizationProgress | null
  path: string
}

type Student = { id: string; name: string }

type Props = { student: Student; periodizations: PeriodizationSummary[] }

export default function PeriodizationsIndex({ student, periodizations }: Props) {
  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Todas as periodizações de {student.name}, da mais recente para a mais
          antiga.
        </p>
      </PageHeader>

      {periodizations.length === 0 ? (
        <div className="rounded-xl border border-dashed bg-muted/20 p-6 text-center text-sm text-muted-foreground">
          Este aluno ainda não passou por nenhuma periodização.
        </div>
      ) : (
        <ol className="flex flex-col gap-3">
          {periodizations.map((periodization, index) => (
            <motion.li
              key={periodization.id}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: 0.4,
                delay: Math.min(index, 6) * 0.05,
                ease: [0.16, 1, 0.3, 1],
              }}
            >
              <PeriodizationCard periodization={periodization} />
            </motion.li>
          ))}
        </ol>
      )}

      <div className="flex justify-start">
        <Button asChild variant="outline" className="h-11 sm:h-10">
          <Link href={`/students/${student.id}`}>Voltar ao aluno</Link>
        </Button>
      </div>
    </>
  )
}

function PeriodizationCard({
  periodization,
}: {
  periodization: PeriodizationSummary
}) {
  const { ordinal, archived, workouts, progress } = periodization

  return (
    <Link
      href={periodization.path}
      className={cn(
        "flex flex-col gap-3 rounded-xl border p-4 transition-colors",
        archived
          ? "bg-muted/20 hover:bg-muted/40"
          : "border-primary bg-primary/5 hover:bg-primary/10",
      )}
    >
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-medium">Periodização {ordinal}</span>
        {!archived && <Badge className="ml-auto">Ativa</Badge>}
      </div>

      <p className="text-sm text-muted-foreground">
        {formatRange(periodization)}
      </p>

      <p className="text-sm">
        <span className="font-medium">{workoutsLabel(workouts.length)}</span>
        {workouts.length > 0 && (
          <span className="text-muted-foreground">
            {" · "}
            {workouts.map((workout) => workout.name).join(" · ")}
          </span>
        )}
      </p>

      {progress && <SessionsProgress progress={progress} archived={archived} />}
    </Link>
  )
}

function SessionsProgress({
  progress,
  archived,
}: {
  progress: PeriodizationProgress
  archived: boolean
}) {
  const { target, sessionsDone, overdue, due } = progress
  const pct =
    target === 0 ? 0 : Math.min(100, Math.round((sessionsDone / target) * 100))
  // due/overdue are forward-looking — archived blocks get the neutral bar.
  const indicatorClass = archived
    ? ""
    : overdue
      ? "[&_[data-slot=progress-indicator]]:bg-destructive"
      : due
        ? "[&_[data-slot=progress-indicator]]:bg-amber-500"
        : ""

  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <span>Sessões</span>
        <span className="tabular-nums">
          {sessionsDone}/{target}
        </span>
      </div>
      <Progress value={pct} className={indicatorClass} />
    </div>
  )
}

function workoutsLabel(count: number): string {
  if (count === 0) return "Nenhum treino"
  return count === 1 ? "1 treino" : `${count} treinos`
}

const DATE_FORMATTER_PT = new Intl.DateTimeFormat("pt-BR", {
  dateStyle: "short",
})

function formatRange({
  startedOn,
  endedOn,
  lengthWeeks,
}: PeriodizationSummary): string {
  const start = formatDate(startedOn)
  const range = endedOn ? `${start} — ${formatDate(endedOn)}` : `desde ${start}`
  if (lengthWeeks == null) return range
  const weeks = lengthWeeks === 1 ? "1 semana" : `${lengthWeeks} semanas`
  return `${range} · ${weeks}`
}

function formatDate(iso: string): string {
  const [y, m, d] = iso.split("-").map((part) => Number(part))
  return DATE_FORMATTER_PT.format(new Date(y!, (m ?? 1) - 1, d ?? 1))
}
