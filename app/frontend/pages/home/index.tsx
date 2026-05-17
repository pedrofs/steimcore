import { Link, router } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { ChevronRightIcon } from "lucide-react"
import type { DashboardQueue, DashboardTag, PrintQueue, PrintQueueRow } from "@/types"

type Props = {
  queue: DashboardQueue
  printQueue: PrintQueue
  totalStudents: number
}

const TAG_LABEL: Record<DashboardTag, string> = {
  plan_needs_action: "Plano precisa ação",
  inactive: "Inativo",
  no_plan: "Sem plano",
  anamnesis_pending: "Anamnese pendente",
}

const TAG_HREF: Record<DashboardTag, string> = {
  plan_needs_action: "/students?status=plan_needs_action",
  inactive: "/students?status=inactive",
  no_plan: "/students?status=no_plan",
  anamnesis_pending: "/students?status=anamnesis_pending",
}

export default function Home({ queue, printQueue, totalStudents }: Props) {
  if (totalStudents === 0) {
    return (
      <>
        <PageHeader />
        <ZeroStudentsCta />
      </>
    )
  }

  return (
    <>
      <PageHeader />
      <CountsStrip counts={queue.counts} />
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <PrintCard printQueue={printQueue} />
        {queue.rows.length === 0 ? <CaughtUpEmptyState /> : <QueueList rows={queue.rows} />}
      </div>
    </>
  )
}

function ZeroStudentsCta() {
  return (
    <div className="flex flex-col items-start gap-3 rounded-xl border border-dashed bg-muted/20 p-6">
      <p className="text-sm text-muted-foreground">
        Cadastre seu primeiro aluno para começar a acompanhar treinos.
      </p>
      <Button asChild className="h-11 sm:h-10">
        <Link href="/students/new">Cadastre seu primeiro aluno</Link>
      </Button>
    </div>
  )
}

function CountsStrip({ counts }: { counts: DashboardQueue["counts"] }) {
  const entries: Array<{ tag: DashboardTag; count: number }> = [
    { tag: "plan_needs_action", count: counts.planNeedsAction },
    { tag: "inactive", count: counts.inactive },
    { tag: "no_plan", count: counts.noPlan },
    { tag: "anamnesis_pending", count: counts.anamnesisPending },
  ]

  return (
    <div className="flex flex-wrap gap-2">
      {entries.map(({ tag, count }) => (
        <Link
          key={tag}
          href={TAG_HREF[tag]}
          className="inline-flex items-center gap-2 rounded-full border bg-card px-3 py-1.5 text-sm transition-colors hover:bg-muted/40"
        >
          <span className="text-muted-foreground">{TAG_LABEL[tag]}</span>
          <span className="font-semibold tabular-nums">{count}</span>
        </Link>
      ))}
    </div>
  )
}

function CaughtUpEmptyState() {
  return (
    <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
      Tudo em dia. Nenhum aluno precisando de atenção agora.
    </p>
  )
}

function QueueList({ rows }: { rows: DashboardQueue["rows"] }) {
  return (
    <ul className="flex flex-col gap-2">
      {rows.map((row) => (
        <li key={row.student.id}>
          <Link
            href={`/students/${row.student.id}`}
            className="flex items-center justify-between gap-3 rounded-xl border bg-card p-4 transition-colors hover:bg-muted/40"
          >
            <div className="flex min-w-0 flex-col gap-2">
              <span className="truncate text-base font-medium">{row.student.name}</span>
              <div className="flex flex-wrap gap-1.5">
                {row.tags.map((tag) => (
                  <Badge key={tag} variant="secondary" className="font-normal">
                    {TAG_LABEL[tag]}
                  </Badge>
                ))}
              </div>
            </div>
            <ChevronRightIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
          </Link>
        </li>
      ))}
    </ul>
  )
}

function PrintCard({ printQueue }: { printQueue: PrintQueue }) {
  const isEmpty = printQueue.rows.length === 0
  return (
    <section className="flex flex-col gap-3 rounded-xl border bg-card p-4">
      <header className="text-base font-semibold">
        {isEmpty ? "Imprimir" : `Imprimir (${printQueue.count})`}
      </header>
      {isEmpty ? (
        <p className="text-sm text-muted-foreground">
          Nenhuma periodização pendente de impressão.
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {printQueue.rows.map((row) => (
            <PrintRow key={row.version.id} row={row} />
          ))}
        </ul>
      )}
    </section>
  )
}

function PrintRow({ row }: { row: PrintQueueRow }) {
  const printablePath = `/students/${row.student.id}/periodization/printable`
  const markPrintedPath = `/students/${row.student.id}/periodizations/${row.periodization.id}/versions/${row.version.id}/print_confirmation`

  return (
    <li className="flex flex-col gap-2 rounded-lg border bg-background p-3">
      <div className="flex min-w-0 flex-col gap-0.5">
        <span className="truncate text-sm font-medium">{row.student.name}</span>
        <span className="text-xs text-muted-foreground">
          {createdAgoLabel(row.version.createdAt)}
        </span>
      </div>
      <div className="flex flex-wrap gap-2">
        <Button asChild size="sm">
          <Link href={printablePath}>Imprimir</Link>
        </Button>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => router.post(markPrintedPath)}
        >
          Marcar como impresso
        </Button>
      </div>
    </li>
  )
}

function createdAgoLabel(createdAtIso: string): string {
  const createdAt = new Date(createdAtIso)
  if (Number.isNaN(createdAt.getTime())) return ""
  const diffDays = Math.max(0, Math.floor((Date.now() - createdAt.getTime()) / 86_400_000))
  if (diffDays === 0) return "Criado hoje"
  if (diffDays === 1) return "Criado há 1 dia"
  return `Criado há ${diffDays} dias`
}
