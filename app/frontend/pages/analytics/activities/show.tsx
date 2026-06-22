import { AnalyticsTabs } from "@/components/analytics-tabs"
import { ChartCard, type Segment } from "@/components/analytics-charts"
import { PageHeader } from "@/components/page-header"

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

const SESSION_SEGMENTS: Segment[] = [
  { key: "trainer", label: "Pelo treinador", color: "var(--chart-1)" },
  { key: "student", label: "Pelo aluno", color: "var(--chart-2)" },
]

const PERIODIZATION_SEGMENTS: Segment[] = [
  { key: "count", label: "Periodizações", color: "var(--chart-1)" },
]

export default function AnalyticsActivitiesShow({ trainingSessions, periodizations }: Props) {
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

      <AnalyticsTabs />

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

function EmptyState() {
  return (
    <p className="rounded-xl border border-dashed bg-muted/20 p-6 text-sm text-muted-foreground">
      Ainda não há atividade nos últimos 14 dias. Assim que seus alunos treinarem
      ou você criar periodizações, os gráficos aparecem aqui.
    </p>
  )
}
