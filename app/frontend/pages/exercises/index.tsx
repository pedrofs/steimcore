import { Link, router } from "@inertiajs/react"
import { useEffect, useRef, useState } from "react"
import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ImageIcon,
} from "lucide-react"

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

type ExerciseSummary = {
  id: string
  name: string
  family: string | null
  muscleGroup: string | null
  state: "unenriched" | "enriched"
  hasMedia: boolean
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
  state: "unenriched" | "enriched" | null
}

type Props = {
  exercises: ExerciseSummary[]
  pagination: PaginationProps
  filters: Filters
}

const SEARCH_DEBOUNCE_MS = 250

export default function Index({ exercises, pagination, filters }: Props) {
  const hasActiveFilters = filters.q !== "" || filters.state !== null
  const catalogIsEmpty = exercises.length === 0 && !hasActiveFilters

  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Catálogo global de exercícios. Anexe mídia e confirme família e grupo
          muscular para enriquecer cada exercício.
        </p>
      </PageHeader>

      {catalogIsEmpty ? (
        <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
          Nenhum exercício no catálogo ainda. Eles surgem automaticamente
          conforme a IA gera periodizações.
        </p>
      ) : (
        <>
          <Toolbar filters={filters} />

          {exercises.length === 0 ? (
            <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
              Nenhum exercício corresponde a esses filtros.{" "}
              <Link
                href="/exercises"
                className="font-medium text-foreground underline-offset-4 hover:underline"
              >
                Limpar filtros
              </Link>
            </p>
          ) : (
            <>
              <ul className="flex flex-col gap-2 md:hidden">
                {exercises.map((exercise) => (
                  <li key={exercise.id}>
                    <Link
                      href={`/exercises/${exercise.id}`}
                      className="flex flex-col gap-1 rounded-xl border bg-card p-4 transition-colors hover:bg-muted/40"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <span className="text-base font-medium">
                          {exercise.name}
                        </span>
                        <StateBadge state={exercise.state} />
                      </div>
                      <span className="text-sm text-muted-foreground">
                        {summaryLine(exercise)}
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
                      <TableHead>Família</TableHead>
                      <TableHead>Grupo muscular</TableHead>
                      <TableHead>Estado</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {exercises.map((exercise) => (
                      <TableRow key={exercise.id}>
                        <TableCell className="font-medium">
                          <Link
                            href={`/exercises/${exercise.id}`}
                            className="hover:underline"
                          >
                            {exercise.name}
                          </Link>
                        </TableCell>
                        <TableCell className="text-muted-foreground">
                          {exercise.family ?? "—"}
                        </TableCell>
                        <TableCell className="text-muted-foreground">
                          {exercise.muscleGroup ?? "—"}
                        </TableCell>
                        <TableCell>
                          <StateBadge state={exercise.state} />
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
  if (filters.state) params.set("state", filters.state)
  params.set("page", String(page))
  return `/exercises?${params.toString()}`
}

function Toolbar({ filters }: { filters: Filters }) {
  const [q, setQ] = useState(filters.q)
  const debouncedRef = useRef<number | null>(null)
  const lastReloadedQ = useRef(filters.q)

  useEffect(() => {
    if (filters.q === lastReloadedQ.current) return
    setQ(filters.q)
    lastReloadedQ.current = filters.q
  }, [filters.q])

  useEffect(
    () => () => {
      if (debouncedRef.current != null) window.clearTimeout(debouncedRef.current)
    },
    [],
  )

  const reload = (next: Partial<Filters>) => {
    const merged = { ...filters, ...next }
    router.reload({
      only: ["exercises", "pagination", "filters"],
      replace: true,
      data: {
        q: merged.q || undefined,
        state: merged.state || undefined,
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

  const toggleState = (state: "unenriched" | "enriched") =>
    reload({ state: filters.state === state ? null : state })

  return (
    <div className="flex flex-col gap-2 md:flex-row md:items-center md:gap-3">
      <Input
        type="search"
        value={q}
        onChange={(e) => handleSearchChange(e.target.value)}
        placeholder="Buscar por nome ou variante"
        aria-label="Buscar exercício"
        className="md:max-w-sm"
      />
      <div className="flex flex-wrap gap-2">
        <FilterChip
          active={filters.state === "unenriched"}
          onClick={() => toggleState("unenriched")}
        >
          Sem mídia
        </FilterChip>
        <FilterChip
          active={filters.state === "enriched"}
          onClick={() => toggleState("enriched")}
        >
          Enriquecidos
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

function StateBadge({ state }: { state: "unenriched" | "enriched" }) {
  if (state === "enriched") {
    return (
      <Badge variant="default">
        <ImageIcon className="size-3" />
        Enriquecido
      </Badge>
    )
  }
  return <Badge variant="outline">Sem mídia</Badge>
}

function summaryLine(exercise: ExerciseSummary): string {
  const parts: string[] = []
  if (exercise.family) parts.push(exercise.family)
  if (exercise.muscleGroup) parts.push(exercise.muscleGroup)
  return parts.length > 0 ? parts.join(" · ") : "Sem classificação"
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
        Mostrando {pagination.from}–{pagination.to} de {pagination.count}{" "}
        exercícios
      </p>
      <Pagination className="sm:mx-0 sm:w-auto sm:justify-end">
        <PaginationContent>
          <PaginationItem>
            <PageButton
              page={pagination.prev}
              filters={filters}
              ariaLabel="Página anterior"
              disabled={pagination.prev == null}
              size="default"
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
              size="default"
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
  size = "icon",
  children,
}: {
  page: number | null
  filters: Filters
  ariaLabel: string
  isActive?: boolean
  disabled?: boolean
  size?: "icon" | "default"
  children: React.ReactNode
}) {
  if (disabled || page == null) {
    return (
      <Button
        type="button"
        variant="ghost"
        size={size}
        aria-label={ariaLabel}
        aria-disabled
        disabled
      >
        {children}
      </Button>
    )
  }

  return (
    <Button asChild variant={isActive ? "outline" : "ghost"} size={size}>
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
