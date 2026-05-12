import { Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import {
  Pagination,
  PaginationContent,
  PaginationEllipsis,
  PaginationItem,
} from "@/components/ui/pagination"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { ChevronLeftIcon, ChevronRightIcon } from "lucide-react"

type StudentSummary = {
  id: string
  name: string
  primaryGoal: string | null
  weeklyFrequency: number | null
}

type PaginationProps = {
  page: number
  pages: number
  count: number
  from: number
  to: number
  prev: number | null
  next: number | null
  series: Array<number | string>
}

type Props = {
  students: StudentSummary[]
  pagination: PaginationProps
}

export default function Index({ students, pagination }: Props) {
  return (
    <>
      <PageHeader
        actions={
          <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
            <Link href="/students/new">Novo aluno</Link>
          </Button>
        }
      />

      {students.length === 0 ? (
        <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
          Nenhum aluno cadastrado ainda. Toque em &quot;Novo aluno&quot;
          para começar.
        </p>
      ) : (
        <>
          <ul className="flex flex-col gap-2 md:hidden">
            {students.map((student) => (
              <li key={student.id}>
                <Link
                  href={`/students/${student.id}`}
                  className="flex flex-col gap-1 rounded-xl border bg-card p-4 transition-colors hover:bg-muted/40"
                >
                  <span className="text-base font-medium">
                    {student.name}
                  </span>
                  <span className="text-sm text-muted-foreground">
                    {summaryLine(student)}
                  </span>
                </Link>
              </li>
            ))}
          </ul>

          <div className="hidden rounded-xl border bg-card md:block">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nome</TableHead>
                  <TableHead>Objetivo</TableHead>
                  <TableHead>Frequência semanal</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {students.map((student) => (
                  <TableRow key={student.id}>
                    <TableCell className="font-medium">
                      <Link
                        href={`/students/${student.id}`}
                        className="hover:underline"
                      >
                        {student.name}
                      </Link>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {student.primaryGoal ?? "—"}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {student.weeklyFrequency != null
                        ? `${student.weeklyFrequency}×/semana`
                        : "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          {pagination.pages > 1 && <PaginationBar pagination={pagination} />}
        </>
      )}
    </>
  )
}

function PaginationBar({ pagination }: { pagination: PaginationProps }) {
  return (
    <div className="flex flex-col items-center gap-2 sm:flex-row sm:justify-between">
      <p className="text-sm text-muted-foreground">
        Mostrando {pagination.from}–{pagination.to} de {pagination.count} alunos
      </p>
      <Pagination className="sm:mx-0 sm:w-auto sm:justify-end">
        <PaginationContent>
          <PaginationItem>
            <PageButton
              page={pagination.prev}
              ariaLabel="Página anterior"
              disabled={pagination.prev == null}
            >
              <ChevronLeftIcon data-icon="inline-start" />
              <span className="hidden sm:block">Anterior</span>
            </PageButton>
          </PaginationItem>

          {pagination.series.map((item, idx) => {
            if (item === "gap") {
              return (
                <PaginationItem key={`gap-${idx}`}>
                  <PaginationEllipsis />
                </PaginationItem>
              )
            }

            const isActive = typeof item === "string"
            const pageNum = typeof item === "string" ? Number(item) : item

            return (
              <PaginationItem key={pageNum}>
                <PageButton
                  page={pageNum}
                  ariaLabel={`Página ${pageNum}`}
                  isActive={isActive}
                >
                  {pageNum}
                </PageButton>
              </PaginationItem>
            )
          })}

          <PaginationItem>
            <PageButton
              page={pagination.next}
              ariaLabel="Próxima página"
              disabled={pagination.next == null}
            >
              <span className="hidden sm:block">Próxima</span>
              <ChevronRightIcon data-icon="inline-end" />
            </PageButton>
          </PaginationItem>
        </PaginationContent>
      </Pagination>
    </div>
  )
}

function PageButton({
  page,
  ariaLabel,
  isActive,
  disabled,
  children,
}: {
  page: number | null
  ariaLabel: string
  isActive?: boolean
  disabled?: boolean
  children: React.ReactNode
}) {
  if (disabled || page == null) {
    return (
      <Button
        type="button"
        variant="ghost"
        size="icon"
        aria-label={ariaLabel}
        aria-disabled
        disabled
      >
        {children}
      </Button>
    )
  }

  return (
    <Button
      asChild
      variant={isActive ? "outline" : "ghost"}
      size="icon"
    >
      <Link
        href={`/students?page=${page}`}
        aria-label={ariaLabel}
        aria-current={isActive ? "page" : undefined}
        preserveScroll
      >
        {children}
      </Link>
    </Button>
  )
}

function summaryLine(student: StudentSummary): string {
  const parts: string[] = []
  if (student.primaryGoal) parts.push(student.primaryGoal)
  if (student.weeklyFrequency != null)
    parts.push(`${student.weeklyFrequency}x/semana`)
  return parts.length > 0 ? parts.join(" · ") : "Sem dados estruturados"
}
