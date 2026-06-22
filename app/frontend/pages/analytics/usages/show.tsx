import { AnalyticsTabs } from "@/components/analytics-tabs"
import { ChartCard, type Segment } from "@/components/analytics-charts"
import { PageHeader } from "@/components/page-header"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"

type DayCount = { date: string; label: string; count: number }

type SessionFunnel = {
  started: number
  finished: number
  cancelled: number
  completionRate: number
  abandonmentRate: number
}

type AppOpenState = { state: string; count: number }

type Totals = { activeStudents: number; homeViews: number; events: number }

type Props = {
  activeStudents: DayCount[]
  sessionFunnel: SessionFunnel
  appOpenStates: AppOpenState[]
  totals: Totals
}

const ACTIVE_SEGMENTS: Segment[] = [
  { key: "count", label: "Alunos ativos", color: "var(--chart-1)" },
]

// entry_state values from Student::HomeController#entry_state_for, in funnel order.
const STATE_LABELS: Record<string, string> = {
  resume: "Retomaram um treino",
  can_start: "Prontos para treinar",
  rest_day: "Dia de descanso",
  no_plan: "Sem plano pronto",
}

export default function AnalyticsUsagesShow({
  activeStudents,
  sessionFunnel,
  appOpenStates,
  totals,
}: Props) {
  const hasData = totals.events > 0

  return (
    <div className="flex flex-col gap-6">
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Como seus alunos usam o app nos últimos 14 dias.
        </p>
      </PageHeader>

      <AnalyticsTabs />

      {!hasData ? (
        <EmptyState />
      ) : (
        <div className="flex flex-col gap-4">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatCard label="Alunos ativos" value={totals.activeStudents} hint="que abriram o app" />
            <StatCard label="Treinos iniciados" value={sessionFunnel.started} />
            <StatCard
              label="Treinos concluídos"
              value={sessionFunnel.finished}
              hint={`${sessionFunnel.completionRate}% de conclusão`}
            />
            <StatCard
              label="Treinos abandonados"
              value={sessionFunnel.cancelled}
              hint={`${sessionFunnel.abandonmentRate}% de abandono`}
            />
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <ChartCard
              title="Alunos ativos por dia"
              description="Alunos distintos com atividade no app a cada dia."
              rows={activeStudents}
              segments={ACTIVE_SEGMENTS}
            />
            <SessionFunnelCard funnel={sessionFunnel} />
          </div>

          <AppOpenStatesCard states={appOpenStates} />
        </div>
      )}
    </div>
  )
}

function StatCard({ label, value, hint }: { label: string; value: number; hint?: string }) {
  return (
    <Card>
      <CardHeader className="gap-1">
        <CardDescription>{label}</CardDescription>
        <CardTitle className="text-3xl font-extrabold tabular-nums">{value}</CardTitle>
      </CardHeader>
      {hint && (
        <CardContent className="pt-0 text-xs text-muted-foreground">{hint}</CardContent>
      )}
    </Card>
  )
}

// Started → finished as a shrinking bar; cancellations are called out separately
// because a cancel hard-deletes its session, so this is the only place they surface.
function SessionFunnelCard({ funnel }: { funnel: SessionFunnel }) {
  const finishedWidth = funnel.started === 0 ? 0 : (funnel.finished / funnel.started) * 100

  return (
    <Card>
      <CardHeader>
        <CardTitle>Funil de treinos</CardTitle>
        <CardDescription>Do início à conclusão.</CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <FunnelRow label="Iniciados" value={funnel.started} width={100} />
        <FunnelRow
          label="Concluídos"
          value={funnel.finished}
          width={finishedWidth}
          caption={`${funnel.completionRate}%`}
        />
        <div className="flex items-baseline justify-between border-t pt-3 text-sm">
          <span className="text-muted-foreground">Abandonados</span>
          <span className="tabular-nums">
            {funnel.cancelled}
            <span className="ml-1 text-xs text-muted-foreground">
              ({funnel.abandonmentRate}%)
            </span>
          </span>
        </div>
      </CardContent>
    </Card>
  )
}

function FunnelRow({
  label,
  value,
  width,
  caption,
}: {
  label: string
  value: number
  width: number
  caption?: string
}) {
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-baseline justify-between text-sm">
        <span className="text-muted-foreground">{label}</span>
        <span className="tabular-nums">
          {value}
          {caption && <span className="ml-1 text-xs text-muted-foreground">{caption}</span>}
        </span>
      </div>
      <div className="h-2.5 overflow-hidden rounded-full bg-muted">
        <div
          className="h-full rounded-full bg-[var(--chart-1)]"
          style={{ width: `${Math.max(width, value > 0 ? 4 : 0)}%` }}
        />
      </div>
    </div>
  )
}

// What students face when they open the app — the richest usage signal, since it
// shows how often an open could (or couldn't) turn into a workout.
function AppOpenStatesCard({ states }: { states: AppOpenState[] }) {
  const total = states.reduce((sum, s) => sum + s.count, 0)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Ao abrir o app</CardTitle>
        <CardDescription>
          O que o aluno encontra quando entra — {total} aberturas.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {states.map((s) => {
          const width = total === 0 ? 0 : (s.count / total) * 100
          return (
            <div key={s.state} className="flex flex-col gap-1">
              <div className="flex items-baseline justify-between text-sm">
                <span className="text-muted-foreground">
                  {STATE_LABELS[s.state] ?? s.state}
                </span>
                <span className="tabular-nums">{s.count}</span>
              </div>
              <div className="h-2.5 overflow-hidden rounded-full bg-muted">
                <div
                  className="h-full rounded-full bg-[var(--chart-2)]"
                  style={{ width: `${Math.max(width, s.count > 0 ? 4 : 0)}%` }}
                />
              </div>
            </div>
          )
        })}
      </CardContent>
    </Card>
  )
}

function EmptyState() {
  return (
    <p className="rounded-xl border border-dashed bg-muted/20 p-6 text-sm text-muted-foreground">
      Ainda não há dados de uso nos últimos 14 dias. Assim que seus alunos abrirem
      o app e treinarem, as métricas aparecem aqui.
    </p>
  )
}
