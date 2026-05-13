import { Link, router } from "@inertiajs/react"
import {
  AlertTriangle,
  Archive,
  ChevronRight,
  Mic,
  Pencil,
  Play,
  RotateCcw,
  Sparkles,
} from "lucide-react"
import { motion } from "motion/react"

import { Markdown } from "@/components/markdown"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { cn } from "@/lib/utils"

type VersionStatus = "pending" | "generating" | "completed" | "failed"

type ActivePlan = {
  periodizationId: string
  versionStatus: VersionStatus | null
  nextWorkout: { name: string; position: number; total: number } | null
  lastSessionAt: string | null
  activeSessionId: string | null
}

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
  archivedAt: string | null
  activePeriodizationId: string | null
  activePlan: ActivePlan | null
}

type FrequencySession = {
  id: string
  createdAt: string
  periodizationVersionId: string | null
  paletteSlot: number | null
  workoutNameSnapshot: string
  workoutPositionSnapshot: number
  trainerEmailPrefix: string
}

type FrequencyDay = {
  date: string
  sessions: FrequencySession[]
}

type FrequencyVersion = {
  id: string
  number: number
  periodizationId: string
  paletteSlot: number
  rangeStart: string
  rangeEnd: string
  isCurrent: boolean
}

type Frequency = {
  windowStart: string
  windowEnd: string
  today: string
  days: FrequencyDay[]
  versions: FrequencyVersion[]
}

type Props = {
  student: Student
  frequency: Frequency | null
}

export default function Show({ student, frequency }: Props) {
  return (
    <>
      <StudentIdentity student={student} />

      {student.archived && <ArchivedBanner student={student} />}

      <div
        className={cn(
          "flex flex-col gap-6 transition-[opacity,filter] duration-300",
          student.archived && "opacity-60",
        )}
      >
        {!student.archived && (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.075, ease: [0.16, 1, 0.3, 1] }}
          >
            <PlanHeroCard student={student} plan={student.activePlan} />
          </motion.div>
        )}

        {!student.archived && frequency && (
          <FrequencySection frequency={frequency} studentId={student.id} />
        )}

        <motion.section
          className="flex flex-col gap-2"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.4, delay: 0.15, ease: "easeOut" }}
        >
          <h2 className="text-lg font-medium">Anamnese</h2>
          <Markdown
            content={student.anamnesisMd}
            placeholder="Sem anamnese registrada ainda."
            emptyAction={
              !student.archived ? (
                <Button asChild size="sm" variant="outline">
                  <Link href={`/students/${student.id}/voice_recordings/new`}>
                    Gravar agora
                  </Link>
                </Button>
              ) : undefined
            }
          />
        </motion.section>

        <motion.section
          className="flex flex-col gap-2"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.4, delay: 0.2, ease: "easeOut" }}
        >
          <h2 className="text-lg font-medium">Observações</h2>
          <Markdown
            content={student.notesMd}
            placeholder="Sem observações."
            emptyAction={
              !student.archived ? (
                <Button asChild size="sm" variant="outline">
                  <Link href={`/students/${student.id}/edit`}>
                    Adicionar observação
                  </Link>
                </Button>
              ) : undefined
            }
          />
        </motion.section>
      </div>

      <div aria-hidden className="h-20 sm:h-0" />

      {!student.archived && <RecordingFab studentId={student.id} />}
    </>
  )
}

function ArchivedBanner({ student }: { student: Student }) {
  const archivedDate = formatArchivedDate(student.archivedAt)

  return (
    <aside
      role="status"
      className="flex flex-col gap-3 rounded-xl border border-dashed border-muted-foreground/30 bg-muted/40 p-4 sm:flex-row sm:items-center sm:justify-between"
    >
      <div className="flex items-start gap-2">
        <Archive
          className="mt-0.5 size-4 shrink-0 text-muted-foreground"
          aria-hidden
        />
        <div className="flex flex-col gap-0.5">
          <span className="text-sm font-medium">Aluno arquivado</span>
          {archivedDate && (
            <span className="text-xs text-muted-foreground">
              Arquivado em {archivedDate}
            </span>
          )}
        </div>
      </div>
      <Button
        variant="outline"
        className="h-11 w-full sm:h-10 sm:w-auto"
        onClick={() =>
          router.post(
            `/students/${student.id}/restoration`,
            {},
            { preserveScroll: true },
          )
        }
      >
        <RotateCcw className="size-4" />
        Restaurar
      </Button>
    </aside>
  )
}

function formatArchivedDate(iso: string | null): string | null {
  if (!iso) return null
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return null
  return new Intl.DateTimeFormat("pt-BR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date)
}

function RecordingFab({ studentId }: { studentId: string }) {
  function handlePress() {
    if (typeof navigator !== "undefined" && "vibrate" in navigator) {
      navigator.vibrate(10)
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.5 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.4, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.95 }}
      className={cn(
        "fixed z-40",
        "bottom-[max(1rem,calc(env(safe-area-inset-bottom)+0.5rem))]",
        "right-[max(1rem,env(safe-area-inset-right))]",
        "sm:bottom-6 sm:right-6",
      )}
    >
      <Link
        href={`/students/${studentId}/voice_recordings/new`}
        aria-label="Gravar anamnese"
        title="Gravar anamnese"
        onPointerDown={handlePress}
        className={cn(
          "group inline-flex items-center justify-center",
          "size-14 sm:size-16 rounded-full",
          "bg-primary text-primary-foreground shadow-lg shadow-foreground/20",
          "ring-2 ring-transparent ring-offset-2 ring-offset-background",
          "transition-[box-shadow,ring-color] duration-150 ease-out",
          "hover:shadow-xl hover:shadow-foreground/25",
          "active:ring-brand/40",
          "focus-visible:outline-none focus-visible:ring-brand/50",
        )}
      >
        <Mic className="size-6" aria-hidden />
      </Link>
    </motion.div>
  )
}

function StudentIdentity({ student }: { student: Student }) {
  const chips = buildChips(student)
  const restriction = (student.restrictionsSummary ?? "").trim()
  const hasRestriction = restriction.length > 0

  return (
    <header className="flex flex-col gap-3">
      <div className="flex items-start gap-3">
        <Avatar className="size-12 sm:size-14">
          <AvatarFallback className="bg-brand/10 text-base font-semibold text-brand">
            {initials(student.name)}
          </AvatarFallback>
        </Avatar>
        <div className="flex min-w-0 flex-1 flex-col gap-1.5">
          <div className="flex items-start justify-between gap-2">
            <h1 className="font-display truncate text-3xl font-bold tracking-tight sm:text-4xl">
              {student.name}
            </h1>
            <Button
              asChild
              variant="ghost"
              size="icon"
              className="-mt-1 -mr-1 size-11 shrink-0 sm:size-10"
              aria-label="Editar perfil"
              title="Editar perfil"
            >
              <Link href={`/students/${student.id}/edit`}>
                <Pencil />
              </Link>
            </Button>
          </div>
          {(chips.length > 0 || student.archived) && (
            <div className="flex flex-wrap items-center gap-1.5">
              {student.archived && (
                <Badge
                  variant="outline"
                  className="border-dashed text-muted-foreground"
                >
                  Arquivado
                </Badge>
              )}
              {chips.map((chip) => (
                <Badge key={chip} variant="secondary">
                  {chip}
                </Badge>
              ))}
            </div>
          )}
        </div>
      </div>
      {hasRestriction && (
        <div className="flex items-start gap-2 rounded-lg border border-amber-300 bg-amber-50/60 p-3 text-sm dark:border-amber-500/40 dark:bg-amber-500/10">
          <AlertTriangle
            className="mt-0.5 size-4 shrink-0 text-amber-700 dark:text-amber-300"
            aria-hidden
          />
          <div className="flex min-w-0 flex-col gap-0.5">
            <span className="text-xs font-medium uppercase tracking-wide text-amber-900 dark:text-amber-200">
              Restrição
            </span>
            <p className="text-amber-950 dark:text-amber-100">{restriction}</p>
          </div>
        </div>
      )}
    </header>
  )
}

const GAP_PX = 3
const LABEL_PX = 24
const WEEKS = 26
const DAY_LABELS = ["Seg", "", "Qua", "", "Sex", "", ""] as const
const MONTH_LABELS_PT = [
  "jan", "fev", "mar", "abr", "mai", "jun",
  "jul", "ago", "set", "out", "nov", "dez",
] as const

// Tailwind cannot detect dynamically-concatenated class names, so the palette
// is enumerated as full literals. Slot indices must match the server-side
// PALETTE_SIZE in Student::FrequencyView.
const PALETTE_BG = [
  "bg-chart-1",
  "bg-chart-2",
  "bg-chart-3",
  "bg-chart-4",
  "bg-chart-5",
] as const

// Per-slot foreground for the desktop position digit, chosen to read against
// each chart-* token's OKLCH lightness (slots with L≳0.6 take dark text).
const PALETTE_TEXT = [
  "text-white",
  "text-white",
  "text-foreground",
  "text-white",
  "text-foreground",
] as const

function paletteBgClass(slot: number | null | undefined): string {
  if (slot == null) return "bg-muted-foreground/55"
  return PALETTE_BG[slot % PALETTE_BG.length] ?? "bg-muted-foreground/55"
}

function paletteTextClass(slot: number | null | undefined): string {
  if (slot == null) return "text-white"
  return PALETTE_TEXT[slot % PALETTE_TEXT.length] ?? "text-white"
}

function FrequencySection({
  frequency,
  studentId,
}: {
  frequency: Frequency
  studentId: string
}) {
  const { days, today, versions } = frequency
  const hasAnySession = days.some((day) => day.sessions.length > 0)

  const versionsById = new Map(versions.map((v) => [v.id, v]))

  const monthLabels: { col: number; label: string }[] = []
  for (let col = 0; col < WEEKS; col++) {
    for (let row = 0; row < 7; row++) {
      const day = days[col * 7 + row]
      if (!day) continue
      const date = parseDateOnly(day.date)
      if (date.getDate() === 1) {
        monthLabels.push({ col, label: MONTH_LABELS_PT[date.getMonth()]! })
        break
      }
    }
  }

  return (
    <motion.section
      className="flex flex-col gap-2"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.4, delay: 0.125, ease: "easeOut" }}
    >
      <h2 className="text-lg font-medium">Frequência</h2>
      <div className="relative overflow-x-auto">
        <div
          className="inline-grid [--fcell:10px] sm:[--fcell:18px]"
          style={{
            gridTemplateColumns: `${LABEL_PX}px repeat(${WEEKS}, var(--fcell))`,
            gridTemplateRows: `auto repeat(7, var(--fcell))`,
            columnGap: `${GAP_PX}px`,
            rowGap: `${GAP_PX}px`,
          }}
          aria-label="Treinos finalizados nos últimos 6 meses"
        >
          {monthLabels.map(({ col, label }) => (
            <div
              key={`m-${col}`}
              className="text-[10px] leading-none text-muted-foreground"
              style={{ gridRow: 1, gridColumn: col + 2 }}
            >
              {label}
            </div>
          ))}

          {DAY_LABELS.map((label, row) => (
            <div
              key={`dl-${row}`}
              className="self-center text-[10px] leading-none text-muted-foreground"
              style={{ gridRow: row + 2, gridColumn: 1 }}
            >
              {label}
            </div>
          ))}

          {days.map((day, i) => {
            const col = Math.floor(i / 7)
            const row = i % 7
            const isToday = day.date === today
            const latest = day.sessions.length > 0 ? day.sessions[day.sessions.length - 1] : undefined
            return (
              <FrequencyCell
                key={day.date}
                day={day}
                latest={latest}
                isToday={isToday}
                row={row}
                col={col}
                version={latest?.periodizationVersionId ? versionsById.get(latest.periodizationVersionId) : undefined}
                studentId={studentId}
              />
            )
          })}
        </div>

        {!hasAnySession && (
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-background/75 px-4 text-center text-xs text-muted-foreground sm:text-sm">
            <span className="max-w-xs">
              Sem treinos finalizados nos últimos 6 meses · O primeiro aparece aqui após Iniciar treino
            </span>
          </div>
        )}
      </div>

      {versions.length > 0 && <FrequencyLegend versions={versions} />}
    </motion.section>
  )
}

function FrequencyCell({
  day,
  latest,
  isToday,
  row,
  col,
  version,
  studentId,
}: {
  day: FrequencyDay
  latest: FrequencySession | undefined
  isToday: boolean
  row: number
  col: number
  version: FrequencyVersion | undefined
  studentId: string
}) {
  const style = { gridRow: row + 2, gridColumn: col + 2 }
  const outlineClass = isToday ? "outline outline-1 outline-foreground/70" : ""

  if (!latest) {
    return (
      <div
        aria-hidden
        style={style}
        className={cn("rounded-sm bg-muted/50", outlineClass)}
      />
    )
  }

  const fillClass = paletteBgClass(latest.paletteSlot)
  const textClass = paletteTextClass(latest.paletteSlot)
  const ariaLabel = `${formatLongDatePt(day.date)} · ${latest.workoutNameSnapshot} · ${latest.trainerEmailPrefix}`

  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          type="button"
          style={style}
          aria-label={ariaLabel}
          className={cn(
            "rounded-sm",
            fillClass,
            outlineClass,
            "flex items-center justify-center overflow-hidden leading-none",
            "cursor-pointer transition-opacity hover:opacity-80",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/50 focus-visible:ring-offset-1 focus-visible:ring-offset-background",
          )}
        >
          <span
            aria-hidden
            className={cn(
              "hidden sm:inline text-[10px] font-semibold tabular-nums",
              textClass,
            )}
          >
            {latest.workoutPositionSnapshot}
          </span>
        </button>
      </PopoverTrigger>
      <PopoverContent align="center" className="w-64 gap-2">
        <div className="text-xs font-medium text-muted-foreground">
          {formatLongDatePt(day.date)}
        </div>
        <div className="text-sm font-semibold">
          {latest.workoutNameSnapshot}{" "}
          <span className="text-xs font-normal text-muted-foreground">
            · Treino {latest.workoutPositionSnapshot}
          </span>
        </div>
        <div className="text-xs text-muted-foreground">
          {latest.trainerEmailPrefix}
        </div>
        {version && (
          <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <span
              aria-hidden
              className={cn("inline-block size-2.5 rounded-sm", paletteBgClass(version.paletteSlot))}
            />
            <span>Versão {version.number} — Periodização</span>
          </div>
        )}
        {version && (
          <Link
            href={`/students/${studentId}/periodizations/${version.periodizationId}`}
            className="inline-flex items-center text-xs font-medium text-brand hover:underline"
          >
            Ver periodização
          </Link>
        )}
      </PopoverContent>
    </Popover>
  )
}

const LONG_DATE_FORMATTER_PT = new Intl.DateTimeFormat("pt-BR", {
  day: "numeric",
  month: "long",
  year: "numeric",
})

function formatLongDatePt(iso: string): string {
  return LONG_DATE_FORMATTER_PT.format(parseDateOnly(iso))
}

function FrequencyLegend({ versions }: { versions: FrequencyVersion[] }) {
  const ordered = [...versions].reverse()
  return (
    <ul className="flex flex-wrap gap-2" aria-label="Legenda das versões da periodização">
      {ordered.map((version) => {
        const range = version.isCurrent
          ? `desde ${formatDayMonth(version.rangeStart)}`
          : `${formatDayMonth(version.rangeStart)} – ${formatDayMonth(version.rangeEnd)}`
        return (
          <li
            key={version.id}
            className="inline-flex items-center gap-1.5 text-xs text-muted-foreground"
          >
            <span
              aria-hidden
              className={cn("inline-block size-2.5 rounded-sm", paletteBgClass(version.paletteSlot))}
            />
            <span>
              <span className="text-foreground">Versão {version.number}</span> · {range}
              {version.isCurrent && <span className="ml-1">(atual)</span>}
            </span>
          </li>
        )
      })}
    </ul>
  )
}

function formatDayMonth(iso: string): string {
  const d = parseDateOnly(iso)
  const dd = String(d.getDate()).padStart(2, "0")
  const mm = String(d.getMonth() + 1).padStart(2, "0")
  return `${dd}/${mm}`
}

function parseDateOnly(iso: string): Date {
  const [y, m, d] = iso.split("-").map((part) => Number(part))
  return new Date(y!, (m ?? 1) - 1, d ?? 1)
}

function PlanHeroCard({
  student,
  plan,
}: {
  student: Student
  plan: ActivePlan | null
}) {
  if (plan == null) {
    return (
      <PlanCardShell tone="muted">
        <PlanCardBody
          eyebrow="Periodização"
          title="Sem plano ativo"
          meta="Crie um plano para começar a treinar com este aluno."
        />
        <PlanCardActions>
          <PlanCardCta
            href={`/students/${student.id}/periodizations/new`}
            label="Criar periodização"
            icon={<Sparkles className="size-4" />}
          />
        </PlanCardActions>
      </PlanCardShell>
    )
  }

  const planHref = `/students/${student.id}/periodizations/${plan.periodizationId}`
  const openPlanCta = (
    <PlanCardCta href={planHref} label="Ver periodização" variant="outline" />
  )

  if (plan.versionStatus == null || plan.versionStatus === "pending" || plan.versionStatus === "generating") {
    return (
      <PlanCardShell tone="accent">
        <PlanCardBody
          eyebrow="Periodização"
          title="Gerando treinos…"
          meta="Os treinos aparecerão aqui em alguns instantes."
          titleClassName="motion-safe:animate-pulse"
        />
        <PlanCardActions>
          <PlanCardCta href={planHref} label="Acompanhar geração" />
        </PlanCardActions>
      </PlanCardShell>
    )
  }

  if (plan.versionStatus === "failed") {
    return (
      <PlanCardShell tone="danger">
        <PlanCardBody
          eyebrow="Periodização"
          title="Geração falhou"
          meta="Veja os detalhes na inbox e gere uma nova versão."
        />
        <PlanCardActions>
          <PlanCardCta href="/inbox" label="Abrir inbox" />
          {openPlanCta}
        </PlanCardActions>
      </PlanCardShell>
    )
  }

  if (plan.activeSessionId) {
    return (
      <PlanCardShell tone="accent">
        <PlanCardBody
          eyebrow="Em andamento"
          title={plan.nextWorkout?.name ?? "Sessão ao vivo"}
          meta="Treino em curso — continue de onde parou."
        />
        <PlanCardActions>
          <PlanCardCta
            href="/training_sessions"
            label="Continuar treino"
            icon={<Play className="size-4 fill-current" />}
          />
          {openPlanCta}
        </PlanCardActions>
      </PlanCardShell>
    )
  }

  if (!plan.nextWorkout) {
    return (
      <PlanCardShell tone="muted">
        <PlanCardBody
          eyebrow="Periodização"
          title="Sem treinos cadastrados"
          meta="Abra a periodização para adicionar treinos."
        />
        <PlanCardActions>
          <PlanCardCta href={planHref} label="Abrir periodização" />
        </PlanCardActions>
      </PlanCardShell>
    )
  }

  const isFirst = plan.lastSessionAt == null
  const eyebrow = isFirst ? "Primeiro treino" : "Próximo treino"
  const lastAgo = timeAgo(plan.lastSessionAt)
  const positionLabel = `Treino ${plan.nextWorkout.position} de ${plan.nextWorkout.total}`
  const meta = lastAgo ? `${positionLabel} · Última ${lastAgo}` : positionLabel

  return (
    <PlanCardShell tone="primary">
      <PlanCardBody eyebrow={eyebrow} title={plan.nextWorkout.name} meta={meta} />
      <PlanCardActions>
        <StartSessionButton studentId={student.id} />
        {openPlanCta}
      </PlanCardActions>
    </PlanCardShell>
  )
}

function PlanCardActions({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">
      {children}
    </div>
  )
}

function PlanCardShell({
  tone,
  children,
}: {
  tone: "primary" | "accent" | "muted" | "danger"
  children: React.ReactNode
}) {
  const toneStyles = {
    primary: "border-brand/20 bg-gradient-to-br from-brand/10 via-brand/5 to-transparent",
    accent: "border-border bg-gradient-to-br from-muted/60 to-transparent",
    muted: "border-dashed border-border bg-muted/20",
    danger: "border-destructive/30 bg-destructive/5",
  }[tone]

  return (
    <section
      className={cn(
        "relative flex flex-col gap-4 rounded-2xl border p-5 shadow-sm sm:p-6",
        toneStyles,
      )}
    >
      {children}
    </section>
  )
}

function PlanCardBody({
  eyebrow,
  title,
  meta,
  titleClassName,
}: {
  eyebrow: string
  title: string
  meta: string
  titleClassName?: string
}) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        {eyebrow}
      </span>
      <h2 className={cn("font-display text-3xl font-extrabold uppercase tracking-tight sm:text-4xl", titleClassName)}>
        {title}
      </h2>
      <p className="text-sm text-muted-foreground">{meta}</p>
    </div>
  )
}

function PlanCardCta({
  href,
  label,
  icon,
  variant = "default",
}: {
  href: string
  label: string
  icon?: React.ReactNode
  variant?: "default" | "outline" | "ghost"
}) {
  return (
    <Button
      asChild
      variant={variant}
      className="h-12 w-full justify-between sm:h-11 sm:w-fit sm:justify-start sm:gap-2 sm:px-4"
    >
      <Link href={href}>
        <span className="inline-flex items-center gap-2">
          {icon}
          {label}
        </span>
        <ChevronRight className="size-4 sm:hidden" />
      </Link>
    </Button>
  )
}

function StartSessionButton({ studentId }: { studentId: string }) {
  return (
    <Button
      onClick={() =>
        router.post(
          "/training_sessions",
          { student_id: studentId },
          { preserveScroll: true },
        )
      }
      className="h-12 w-full justify-between sm:h-11 sm:w-fit sm:justify-start sm:gap-2 sm:px-4"
    >
      <span className="inline-flex items-center gap-2">
        <Play className="size-4 fill-current" />
        Iniciar treino
      </span>
      <ChevronRight className="size-4 sm:hidden" />
    </Button>
  )
}

function buildChips(student: Student): string[] {
  const chips: string[] = []
  if (student.sex) chips.push(student.sex)
  if (student.age != null) chips.push(`${student.age} anos`)
  if (student.weeklyFrequency != null) {
    chips.push(`${student.weeklyFrequency}x/semana`)
  }
  if (student.primaryGoal) chips.push(student.primaryGoal)
  return chips
}

function initials(name: string): string {
  const parts = name
    .trim()
    .split(/\s+/)
    .filter((p) => p.length > 0)
  if (parts.length === 0) return "?"
  if (parts.length === 1) return parts[0]!.charAt(0).toUpperCase()
  const first = parts[0]!.charAt(0)
  const last = parts[parts.length - 1]!.charAt(0)
  return (first + last).toUpperCase()
}

function timeAgo(iso: string | null): string | null {
  if (!iso) return null
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return null

  const fmt = new Intl.RelativeTimeFormat("pt-BR", { numeric: "auto" })
  const diffSec = Math.round((Date.now() - date.getTime()) / 1000)

  const units: [Intl.RelativeTimeFormatUnit, number][] = [
    ["second", 60],
    ["minute", 60],
    ["hour", 24],
    ["day", 30],
    ["month", 12],
    ["year", Number.POSITIVE_INFINITY],
  ]

  let value = diffSec
  for (const [unit, step] of units) {
    if (Math.abs(value) < step) return fmt.format(-value, unit)
    value = Math.round(value / step)
  }
  return null
}
