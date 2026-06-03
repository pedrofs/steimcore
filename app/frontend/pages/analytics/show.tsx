import { PageHeader } from "@/components/page-header"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"

type SessionDay = {
  date: string
  label: string
  trainer: number
  student: number
}

type PeriodizationDay = {
  date: string
  label: string
  count: number
}

type Props = {
  trainingSessions: SessionDay[]
  periodizations: PeriodizationDay[]
}

type Segment = { key: string; label: string; color: string }

const SESSION_SEGMENTS: Segment[] = [
  { key: "trainer", label: "Pelo treinador", color: "var(--chart-1)" },
  { key: "student", label: "Pelo aluno", color: "var(--chart-2)" },
]

const PERIODIZATION_SEGMENTS: Segment[] = [
  { key: "count", label: "Periodizações", color: "var(--chart-1)" },
]

export default function AnalyticsShow({ trainingSessions, periodizations }: Props) {
  const sessionTotal = trainingSessions.reduce((sum, d) => sum + d.trainer + d.student, 0)
  const periodizationTotal = periodizations.reduce((sum, d) => sum + d.count, 0)
  const hasData = sessionTotal > 0 || periodizationTotal > 0

  return (
    <div className="flex flex-col gap-6">
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Atividade dos últimos 14 dias.
        </p>
      </PageHeader>

      {!hasData ? (
        <EmptyState />
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          <ChartCard
            title="Treinos por dia"
            description="Sessões iniciadas, por quem começou."
            rows={trainingSessions}
            segments={SESSION_SEGMENTS}
            showLegend
          />
          <ChartCard
            title="Periodizações por dia"
            description="Planos criados a cada dia."
            rows={periodizations}
            segments={PERIODIZATION_SEGMENTS}
          />
        </div>
      )}
    </div>
  )
}

type Row = { label: string } & Record<string, string | number>

function ChartCard({
  title,
  description,
  rows,
  segments,
  showLegend = false,
}: {
  title: string
  description: string
  rows: Row[]
  segments: Segment[]
  showLegend?: boolean
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {showLegend && <Legend segments={segments} />}
        <StackedBarChart rows={rows} segments={segments} />
      </CardContent>
    </Card>
  )
}

function Legend({ segments }: { segments: Segment[] }) {
  return (
    <div className="flex flex-wrap gap-4">
      {segments.map((s) => (
        <div key={s.key} className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <span className="size-2.5 rounded-[2px]" style={{ backgroundColor: s.color }} />
          {s.label}
        </div>
      ))}
    </div>
  )
}

// Dependency-free stacked bar chart. Bars share a max (the tallest day's total)
// so heights are comparable; a zero day renders a faint baseline stub so it
// reads as "nothing happened" rather than a gap. Native title tooltips keep it
// accessible without a charting runtime.
function StackedBarChart({ rows, segments }: { rows: Row[]; segments: Segment[] }) {
  const totals = rows.map((r) => segments.reduce((sum, s) => sum + (Number(r[s.key]) || 0), 0))
  const max = Math.max(1, ...totals)

  return (
    <div className="flex h-[220px] items-end gap-1">
      {rows.map((row, i) => {
        const total = totals[i]
        const barHeight = total === 0 ? 0 : Math.max(4, (total / max) * 100)
        const tooltip = [
          row.label,
          ...segments.map((s) => `${s.label}: ${Number(row[s.key]) || 0}`),
        ].join(" · ")

        return (
          <div
            key={String(row.label) + i}
            className="flex h-full flex-1 flex-col items-center justify-end gap-1.5"
            title={tooltip}
          >
            <span className="text-[10px] font-medium tabular-nums text-muted-foreground">
              {total > 0 ? total : ""}
            </span>
            {total === 0 ? (
              <div className="h-px w-full bg-border" />
            ) : (
              <div
                className="flex w-full flex-col-reverse overflow-hidden rounded-t"
                style={{ height: `${barHeight}%` }}
              >
                {segments.map((s) => {
                  const value = Number(row[s.key]) || 0
                  if (value === 0) return null
                  return (
                    <div
                      key={s.key}
                      style={{ height: `${(value / total) * 100}%`, backgroundColor: s.color }}
                    />
                  )
                })}
              </div>
            )}
            <span className="text-[10px] tabular-nums text-muted-foreground">{row.label}</span>
          </div>
        )
      })}
    </div>
  )
}

function EmptyState() {
  return (
    <p className="rounded-xl border border-dashed bg-muted/20 p-6 text-sm text-muted-foreground">
      Ainda não há atividade nos últimos 14 dias. Assim que seus alunos treinarem
      ou você criar periodizações, os gráficos aparecem aqui.
    </p>
  )
}
