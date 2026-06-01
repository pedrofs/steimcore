import { Head } from "@inertiajs/react"
import { DumbbellIcon, Sparkles } from "lucide-react"
import { motion, type Variants } from "motion/react"
import { useState } from "react"

import { BrandMonogram } from "@/components/brand"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"

type Exercise = { name: string; detail: string }

type NextWorkout = {
  name: string
  position: number
  totalExercises: number
  preview: Exercise[]
}

type Progress = {
  sessionsDone: number
  target: number
  sessionsRemaining: number
  percent: number
  lengthWeeks: number
}

type SessionSummary = { id: string; workoutName: string | null; exercises: Exercise[] }

type CalendarDay = {
  date: string
  trained: boolean
  isFuture: boolean
  sessions: SessionSummary[]
}

type Dashboard = {
  firstName: string
  today: string
  trainedToday: boolean
  todayWorkoutName: string | null
  nextWorkout: NextWorkout | null
  progress: Progress | null
  calendar: { days: CalendarDay[] }
}

type Props = {
  organizationName?: string | null
  dashboard: Dashboard
}

const WEEKDAY_LABELS = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"] as const

const section: Variants = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0 },
}

function formatWeekday(iso: string) {
  // Noon avoids any TZ rollover landing on the wrong day.
  const date = new Date(`${iso}T12:00:00`)
  return new Intl.DateTimeFormat("pt-BR", { weekday: "long" }).format(date)
}

function formatFullDate(iso: string) {
  const date = new Date(`${iso}T12:00:00`)
  return new Intl.DateTimeFormat("pt-BR", {
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(date)
}

// Saturday and Sunday are rest days — a fixed rule, no per-student schedule.
function isWeekend(iso: string) {
  const weekday = new Date(`${iso}T12:00:00`).getDay()
  return weekday === 0 || weekday === 6
}

export default function StudentHome({ dashboard }: Props) {
  const { firstName, today, trainedToday, todayWorkoutName, nextWorkout, progress, calendar } =
    dashboard
  const [selectedDay, setSelectedDay] = useState<CalendarDay | null>(null)

  return (
    <>
      <Head title="Início" />
      <div className="mx-auto w-full max-w-md">
        <Hero
          firstName={firstName}
          today={today}
          trainedToday={trainedToday}
          todayWorkoutName={todayWorkoutName}
        />

        <motion.div
          className="space-y-4 px-4"
          initial="hidden"
          animate="show"
          transition={{ staggerChildren: 0.09, delayChildren: 0.12 }}
        >
          <motion.div
            variants={section}
            transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
            className="relative z-10 -mt-9"
          >
            <NextWorkoutCard nextWorkout={nextWorkout} />
          </motion.div>

          {progress && (
            <motion.div variants={section} transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}>
              <ProgressCard progress={progress} />
            </motion.div>
          )}

          <motion.div variants={section} transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}>
            <CalendarCard days={calendar.days} today={today} onSelect={setSelectedDay} />
          </motion.div>
        </motion.div>
      </div>

      <SessionSheet day={selectedDay} onClose={() => setSelectedDay(null)} />
    </>
  )
}

function Hero({
  firstName,
  today,
  trainedToday,
  todayWorkoutName,
}: {
  firstName: string
  today: string
  trainedToday: boolean
  todayWorkoutName: string | null
}) {
  return (
    <section className="relative overflow-hidden rounded-b-[2rem] bg-brand px-6 pb-16 pt-[calc(env(safe-area-inset-top)+1.75rem)] text-brand-foreground">
      <BrandMonogram
        title=""
        className="pointer-events-none absolute -top-10 -right-8 h-52 w-52 text-white/10"
      />
      <motion.p
        className="text-sm font-medium text-brand-foreground/85"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: "easeOut" }}
      >
        Olá, {firstName} 👋
      </motion.p>
      <motion.h1
        className="mt-1.5 max-w-[18ch] text-balance font-display text-[2.1rem] font-extrabold uppercase leading-[1.04] tracking-tight"
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.08, ease: [0.16, 1, 0.3, 1] }}
      >
        {trainedToday
          ? `${todayWorkoutName ?? "Treino"} copado hoje! 🎉`
          : isWeekend(today)
            ? `Hoje é ${formatWeekday(today)}, dia de descanso 🧘`
            : `Hoje é ${formatWeekday(today)}, bora treinar? 💪`}
      </motion.h1>
    </section>
  )
}

function CardShell({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={cn("rounded-2xl border bg-card p-5 shadow-lg shadow-brand/5", className)}>
      {children}
    </div>
  )
}

function CardLabel({ children }: { children: React.ReactNode }) {
  return (
    <p className="text-[0.7rem] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
      {children}
    </p>
  )
}

function NextWorkoutCard({ nextWorkout }: { nextWorkout: NextWorkout | null }) {
  if (!nextWorkout) {
    return (
      <CardShell>
        <CardLabel>Próximo treino</CardLabel>
        <div className="mt-3 flex items-start gap-3">
          <div className="grid size-10 shrink-0 place-items-center rounded-xl bg-accent text-accent-foreground">
            <Sparkles className="size-5" />
          </div>
          <div>
            <p className="font-heading font-semibold">Seu plano está chegando</p>
            <p className="mt-0.5 text-sm text-muted-foreground">
              Seu treinador está montando sua periodização. Volte em breve para ver seu próximo
              treino aqui.
            </p>
          </div>
        </div>
      </CardShell>
    )
  }

  const remaining = nextWorkout.totalExercises - nextWorkout.preview.length

  return (
    <CardShell>
      <div className="flex items-center justify-between">
        <CardLabel>Próximo treino</CardLabel>
        <span className="grid size-9 place-items-center rounded-xl bg-brand/10 text-brand">
          <DumbbellIcon className="size-[1.15rem]" />
        </span>
      </div>

      <h2 className="mt-2 font-display text-3xl font-extrabold tracking-tight">
        {nextWorkout.name}
      </h2>

      <ul className="mt-4 space-y-2.5">
        {nextWorkout.preview.map((exercise, i) => (
          <li key={i} className="flex items-baseline justify-between gap-3">
            <span className="flex min-w-0 items-baseline gap-2.5">
              <span className="text-xs font-semibold tabular-nums text-brand">
                {String(i + 1).padStart(2, "0")}
              </span>
              <span className="truncate text-sm font-medium">{exercise.name}</span>
            </span>
            <span className="shrink-0 text-sm tabular-nums text-muted-foreground">
              {exercise.detail}
            </span>
          </li>
        ))}
      </ul>

      {remaining > 0 && (
        <p className="mt-4 border-t pt-3 text-sm text-muted-foreground">
          + {remaining} {remaining === 1 ? "exercício" : "exercícios"} neste treino
        </p>
      )}
    </CardShell>
  )
}

function ProgressCard({ progress }: { progress: Progress }) {
  const done = progress.sessionsRemaining <= 0

  return (
    <CardShell>
      <div className="flex items-end justify-between">
        <div>
          <CardLabel>Sua periodização</CardLabel>
          <p className="mt-2 font-display text-2xl font-bold">
            <span className="text-brand">{progress.sessionsDone}</span>
            <span className="text-muted-foreground"> / {progress.target} treinos</span>
          </p>
        </div>
        <span className="font-display text-3xl font-extrabold tabular-nums text-brand">
          {progress.percent}%
        </span>
      </div>

      <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-muted">
        <motion.div
          className="h-full rounded-full bg-brand"
          initial={{ width: 0 }}
          animate={{ width: `${progress.percent}%` }}
          transition={{ duration: 0.9, delay: 0.35, ease: [0.16, 1, 0.3, 1] }}
        />
      </div>

      <p className="mt-3 text-sm text-muted-foreground">
        {done ? (
          <span className="font-medium text-foreground">
            Meta batida! 🎉 Hora do próximo ciclo.
          </span>
        ) : (
          <>
            Plano de {progress.lengthWeeks}{" "}
            {progress.lengthWeeks === 1 ? "semana" : "semanas"} · faltam{" "}
            <span className="font-medium text-foreground">{progress.sessionsRemaining}</span>{" "}
            {progress.sessionsRemaining === 1 ? "treino" : "treinos"}
          </>
        )}
      </p>
    </CardShell>
  )
}

function CalendarCard({
  days,
  today,
  onSelect,
}: {
  days: CalendarDay[]
  today: string
  onSelect: (day: CalendarDay) => void
}) {
  const trainedCount = days.filter((d) => d.trained).length

  return (
    <CardShell>
      <div className="flex items-end justify-between">
        <CardLabel>Sua frequência</CardLabel>
        <p className="text-sm text-muted-foreground">
          <span className="font-display text-lg font-bold text-foreground">{trainedCount}</span>{" "}
          {trainedCount === 1 ? "treino" : "treinos"} · 5 semanas
        </p>
      </div>

      <div className="mt-4 grid grid-cols-7 gap-1.5">
        {WEEKDAY_LABELS.map((label) => (
          <div
            key={label}
            className="pb-1 text-center text-[0.65rem] font-medium text-muted-foreground"
          >
            {label}
          </div>
        ))}
        {days.map((day, i) => (
          <CalendarCell
            key={day.date}
            day={day}
            isToday={day.date === today}
            weekend={isWeekend(day.date)}
            index={i}
            onSelect={onSelect}
          />
        ))}
      </div>
    </CardShell>
  )
}

const RING = "ring-2 ring-brand ring-offset-2 ring-offset-card"

function CalendarCell({
  day,
  isToday,
  weekend,
  index,
  onSelect,
}: {
  day: CalendarDay
  isToday: boolean
  weekend: boolean
  index: number
  onSelect: (day: CalendarDay) => void
}) {
  // Trained always wins — training on a rest day still earns its mark.
  if (day.trained) {
    return (
      <motion.button
        type="button"
        onClick={() => onSelect(day)}
        aria-label={`Ver treino de ${formatWeekday(day.date)}`}
        className={cn(
          "grid aspect-square place-items-center rounded-lg bg-brand text-brand-foreground shadow-sm shadow-brand/25",
          "motion-safe:active:scale-95",
          isToday && RING
        )}
        initial={{ scale: 0.4, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{
          delay: 0.45 + index * 0.012,
          type: "spring",
          stiffness: 420,
          damping: 24,
        }}
      >
        <BrandMonogram title="" className="h-[58%] w-[58%]" />
      </motion.button>
    )
  }

  // Weekends are rest days: a calm marker, not a "missed workout".
  if (weekend) {
    return (
      <div
        className={cn(
          "grid aspect-square place-items-center rounded-lg bg-muted/40",
          isToday && RING
        )}
      >
        <span className="size-1.5 rounded-full bg-muted-foreground/30" />
      </div>
    )
  }

  if (day.isFuture) {
    return (
      <div
        className={cn(
          "aspect-square rounded-lg border border-dashed border-border/70",
          isToday && "border-solid border-brand/40"
        )}
      />
    )
  }

  return <div className={cn("aspect-square rounded-lg bg-muted", isToday && RING)} />
}

function SessionSheet({ day, onClose }: { day: CalendarDay | null; onClose: () => void }) {
  // Keep the last selected day mounted during the close animation so the sheet
  // doesn't blank out as it slides away.
  const sessions = day?.sessions ?? []
  const title = sessions[0]?.workoutName ?? "Treino"
  const multiple = sessions.length > 1

  return (
    <Sheet open={day !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        side="bottom"
        className="max-h-[min(80vh,calc(100dvh-env(safe-area-inset-top)-1rem))] overflow-y-auto"
      >
        <SheetHeader>
          <SheetTitle className="font-display text-2xl font-extrabold tracking-tight">
            {title}
          </SheetTitle>
          {day && (
            <SheetDescription className="capitalize">{formatFullDate(day.date)}</SheetDescription>
          )}
        </SheetHeader>

        <div className="flex flex-col gap-5 p-4 pt-0">
          {sessions.map((session) => (
            <div key={session.id}>
              {multiple && (
                <p className="mb-2 font-heading text-sm font-semibold">
                  {session.workoutName ?? "Treino"}
                </p>
              )}
              {session.exercises.length > 0 ? (
                <ul className="space-y-2.5">
                  {session.exercises.map((exercise, i) => (
                    <li key={i} className="flex items-baseline justify-between gap-3">
                      <span className="flex min-w-0 items-baseline gap-2.5">
                        <span className="text-xs font-semibold tabular-nums text-brand">
                          {String(i + 1).padStart(2, "0")}
                        </span>
                        <span className="truncate text-sm font-medium">{exercise.name}</span>
                      </span>
                      <span className="shrink-0 text-sm tabular-nums text-muted-foreground">
                        {exercise.detail}
                      </span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-sm text-muted-foreground">Treino registrado.</p>
              )}
            </div>
          ))}
        </div>
      </SheetContent>
    </Sheet>
  )
}
