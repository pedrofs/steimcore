import { Link, router } from "@inertiajs/react"
import { AlertCircleIcon, InboxIcon, Loader2Icon } from "lucide-react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { usePollProps } from "@/hooks/use-poll-props"

type Row = {
  voiceRecordingId: string
  kind: string
  studentId: string
  studentName: string
  label: string
  displayStatus: string
  errorMessage: string | null
  timestamp: string
  url: string | null
}

type Groups = {
  failed: Row[]
  ready: Row[]
  inFlight: Row[]
}

type Props = { groups: Groups }

export default function InboxShow({ groups }: Props) {
  usePollProps(["groups"])

  const isEmpty =
    groups.failed.length === 0 &&
    groups.ready.length === 0 &&
    groups.inFlight.length === 0

  return (
    <>
      <PageHeader />

      {isEmpty && <EmptyState />}

      {groups.failed.length > 0 && (
        <FailedSection rows={groups.failed} />
      )}

      {groups.ready.length > 0 && (
        <ReadySection rows={groups.ready} />
      )}

      {groups.inFlight.length > 0 && (
        <InFlightSection rows={groups.inFlight} />
      )}
    </>
  )
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed bg-muted/20 p-12 text-center">
      <InboxIcon className="size-10 text-muted-foreground" aria-hidden />
      <p className="text-sm text-muted-foreground">Sem trabalhos pendentes.</p>
    </div>
  )
}

function FailedSection({ rows }: { rows: Row[] }) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Falhas</h2>
      <ul className="flex flex-col gap-2">
        {rows.map((row) => (
          <li
            key={row.voiceRecordingId}
            className="flex flex-col gap-3 rounded-xl border border-destructive/30 bg-destructive/5 p-4"
          >
            <div className="flex items-start gap-3">
              <AlertCircleIcon
                className="mt-0.5 size-5 shrink-0 text-destructive"
                aria-hidden
              />
              <div className="flex flex-col gap-1">
                <p className="text-sm font-medium">
                  {row.studentName} — {row.label}
                </p>
                {row.errorMessage && (
                  <p className="text-sm text-muted-foreground">
                    {row.errorMessage}
                  </p>
                )}
                <p className="text-xs text-muted-foreground">
                  {formatRelative(row.timestamp)}
                </p>
              </div>
            </div>
            <div className="flex justify-end">
              <Button
                type="button"
                className="h-11 sm:h-10"
                onClick={() =>
                  router.post(
                    `/students/${row.studentId}/voice_recordings/${row.voiceRecordingId}/retry`,
                  )
                }
              >
                Tentar novamente
              </Button>
            </div>
          </li>
        ))}
      </ul>
    </section>
  )
}

function ReadySection({ rows }: { rows: Row[] }) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Prontos para revisar</h2>
      <ul className="flex flex-col gap-2">
        {rows.map((row) => (
          <li key={row.voiceRecordingId}>
            <Link
              href={row.url ?? "#"}
              className="flex items-center justify-between gap-3 rounded-xl border bg-card p-4 transition-colors hover:bg-muted/40"
            >
              <div className="flex flex-col gap-1">
                <p className="text-sm font-medium">
                  {row.studentName} — {row.label}
                </p>
                <p className="text-xs text-muted-foreground">
                  {formatRelative(row.timestamp)}
                </p>
              </div>
              <Button
                asChild
                variant="outline"
                size="sm"
                className="pointer-events-none h-9"
              >
                <span>Revisar</span>
              </Button>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  )
}

function InFlightSection({ rows }: { rows: Row[] }) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Em andamento</h2>
      <ul className="flex flex-col gap-2">
        {rows.map((row) => (
          <li
            key={row.voiceRecordingId}
            className="flex items-center gap-3 rounded-xl border bg-muted/20 p-4"
          >
            <Loader2Icon
              className="size-5 shrink-0 animate-spin text-muted-foreground"
              aria-hidden
            />
            <div className="flex flex-col gap-1">
              <p className="text-sm font-medium">
                {row.studentName} — {row.label}
              </p>
              <p className="text-xs text-muted-foreground">
                {row.displayStatus}
              </p>
            </div>
          </li>
        ))}
      </ul>
    </section>
  )
}

function formatRelative(timestamp: string): string {
  const then = new Date(timestamp).getTime()
  if (Number.isNaN(then)) return ""
  const diffSeconds = Math.round((Date.now() - then) / 1000)
  if (diffSeconds < 60) return "agora"
  const minutes = Math.round(diffSeconds / 60)
  if (minutes < 60) return `há ${minutes} min`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `há ${hours} h`
  const days = Math.round(hours / 24)
  return `há ${days} d`
}
