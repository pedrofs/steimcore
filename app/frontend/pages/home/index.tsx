import { Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { ChevronRightIcon } from "lucide-react"
import type { DashboardQueue, DashboardTag } from "@/types"

type Props = {
  queue: DashboardQueue
  totalStudents: number
}

const TAG_LABEL: Record<DashboardTag, string> = {
  anamnesis_pending: "Anamnese pendente",
}

const TAG_HREF: Record<DashboardTag, string> = {
  anamnesis_pending: "/students?status=anamnesis_pending",
}

export default function Home({ queue, totalStudents }: Props) {
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
      {queue.rows.length === 0 ? <CaughtUpEmptyState /> : <QueueList rows={queue.rows} />}
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
