import { Link, router } from "@inertiajs/react"
import { useEffect, useRef, useState } from "react"

import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
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
  activePeriodizationId: string | null
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

type Filters = {
  q: string
  withoutActive: boolean
  archived: boolean
  status: "anamnesis_pending" | null
}

type Props = {
  students: StudentSummary[]
  pagination: PaginationProps
  filters: Filters
}

const SEARCH_DEBOUNCE_MS = 250

export default function Index({ students, pagination, filters }: Props) {
  const hasActiveFilters =
    filters.q !== "" || filters.withoutActive || filters.archived || filters.status !== null
  const orgIsEmpty = students.length === 0 && !hasActiveFilters

  return (
    <>
      <PageHeader
        actions={
          <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
            <Link href="/students/new">Novo aluno</Link>
          </Button>
        }
      />

      {orgIsEmpty ? (
        <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
          Nenhum aluno cadastrado ainda. Toque em &quot;Novo aluno&quot;
          para começar.
        </p>
      ) : (
        <>
          <Toolbar filters={filters} />

          {students.length === 0 ? (
            <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
              Nenhum aluno corresponde a esses filtros.{" "}
              <Link
                href="/students"
                className="font-medium text-foreground underline-offset-4 hover:underline"
              >
                Limpar filtros
              </Link>
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
                      <div className="flex items-start justify-between gap-2">
                        <span className="text-base font-medium">
                          {student.name}
                        </span>
                        <PeriodizationBadge
                          activePeriodizationId={student.activePeriodizationId}
                        />
                      </div>
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
                      <TableHead>Periodização</TableHead>
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
                        <TableCell>
                          <PeriodizationBadge
                            activePeriodizationId={
                              student.activePeriodizationId
                            }
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              {pagination.pages > 1 && (
                <PaginationBar pagination={pagination} filters={filters} />
              )}
            </>
          )}
        </>
      )}
    </>
  )
}

function buildPageHref(page: number, filters: Filters): string {
  const params = new URLSearchParams()
  if (filters.q) params.set("q", filters.q)
  if (filters.withoutActive) params.set("without_active", "1")
  if (filters.archived) params.set("archived", "1")
  if (filters.status) params.set("status", filters.status)
  params.set("page", String(page))
  return `/students?${params.toString()}`
}

function Toolbar({ filters }: { filters: Filters }) {
  const [q, setQ] = useState(filters.q)
  const debouncedRef = useRef<number | null>(null)
  const lastReloadedQ = useRef(filters.q)

  useEffect(() => {
    setQ(filters.q)
    lastReloadedQ.current = filters.q
  }, [filters.q])

  useEffect(
    () => () => {
      if (debouncedRef.current != null) window.clearTimeout(debouncedRef.current)
    },
    []
  )

  const reload = (next: Partial<Filters>) => {
    const merged = { ...filters, ...next }
    router.reload({
      only: ["students", "pagination", "filters"],
      preserveState: true,
      preserveScroll: true,
      replace: true,
      data: {
        q: merged.q || undefined,
        without_active: merged.withoutActive ? "1" : undefined,
        archived: merged.archived ? "1" : undefined,
        status: merged.status || undefined,
        page: undefined,
      },
    })
  }

  const handleSearchChange = (value: string) => {
    setQ(value)
    if (debouncedRef.current != null) window.clearTimeout(debouncedRef.current)
    debouncedRef.current = window.setTimeout(() => {
      if (lastReloadedQ.current === value) return
      lastReloadedQ.current = value
      reload({ q: value })
    }, SEARCH_DEBOUNCE_MS)
  }

  const toggleWithoutActive = () =>
    reload({ withoutActive: !filters.withoutActive })

  const toggleArchived = () => reload({ archived: !filters.archived })

  return (
    <div className="flex flex-col gap-2 md:flex-row md:items-center md:gap-3">
      <Input
        type="search"
        value={q}
        onChange={(e) => handleSearchChange(e.target.value)}
        placeholder="Buscar por nome"
        aria-label="Buscar por nome"
        className="md:max-w-sm"
      />
      <div className="flex flex-wrap gap-2">
        <FilterChip active={filters.withoutActive} onClick={toggleWithoutActive}>
          Sem periodização
        </FilterChip>
        <FilterChip active={filters.archived} onClick={toggleArchived}>
          Arquivados
        </FilterChip>
      </div>
    </div>
  )
}

function FilterChip({
  active,
  onClick,
  children,
}: {
  active: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <Button
      type="button"
      variant={active ? "default" : "outline"}
      size="sm"
      onClick={onClick}
      aria-pressed={active}
      className="rounded-full"
    >
      {children}
    </Button>
  )
}

function PeriodizationBadge({
  activePeriodizationId,
}: {
  activePeriodizationId: string | null
}) {
  if (activePeriodizationId) {
    return <Badge variant="default">Ativa</Badge>
  }
  return <Badge variant="outline">Sem periodização</Badge>
}

function PaginationBar({
  pagination,
  filters,
}: {
  pagination: PaginationProps
  filters: Filters
}) {
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
              filters={filters}
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
                  filters={filters}
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
              filters={filters}
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
  filters,
  ariaLabel,
  isActive,
  disabled,
  children,
}: {
  page: number | null
  filters: Filters
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
        href={buildPageHref(page, filters)}
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
