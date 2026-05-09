import { Form, Head, Link, router, usePage } from "@inertiajs/react"
import { Fragment } from "react"
import { Loader2Icon } from "lucide-react"

import { AppSidebar } from "@/components/app-sidebar"
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar"
import { Textarea } from "@/components/ui/textarea"
import { Input } from "@/components/ui/input"
import { useJobStatus } from "@/hooks/use-job-status"

type Workout = {
  id: string
  name: string
  position: number
  contentMd: string
}

type Version = {
  id: string
  status:
    | "pending"
    | "generating"
    | "completed"
    | "failed"
  bodyMd: string
  errorMessage: string | null
  promoted: boolean
  readOnly: boolean
  periodizationId: string
  workouts: Workout[]
}

type Student = { id: string; name: string }

type Props = { version: Version; student: Student }

export default function ShowPeriodizationVersion({ version, student }: Props) {
  const { props } = usePage()
  const title = props.title
  const breadcrumbs = props.breadcrumbs

  useJobStatus(version.status, [ "version", "student", "flash", "errors" ])

  const updatePath = `/periodization_versions/${version.id}`
  const promotePath = `/periodization_versions/${version.id}/promotion`

  return (
    <>
      <Head title={title ?? undefined} />
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <header className="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12">
            <div className="flex items-center gap-2 px-4">
              <SidebarTrigger className="-ml-1 size-11 md:size-8" />
              <Separator
                orientation="vertical"
                className="mr-2 data-vertical:h-4 data-vertical:self-auto"
              />
              <Breadcrumb>
                <BreadcrumbList>
                  {breadcrumbs.map((crumb, i) => {
                    const isLast = i === breadcrumbs.length - 1
                    return (
                      <Fragment key={`${crumb.path}-${i}`}>
                        <BreadcrumbItem>
                          {isLast ? (
                            <BreadcrumbPage>{crumb.label}</BreadcrumbPage>
                          ) : (
                            <BreadcrumbLink asChild>
                              <Link href={crumb.path}>{crumb.label}</Link>
                            </BreadcrumbLink>
                          )}
                        </BreadcrumbItem>
                        {!isLast && <BreadcrumbSeparator />}
                      </Fragment>
                    )
                  })}
                </BreadcrumbList>
              </Breadcrumb>
            </div>
          </header>
          <div className="flex flex-1 flex-col gap-6 p-4 pt-0">
            <div className="flex flex-col gap-1">
              {title && (
                <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                  {title}
                </h1>
              )}
              <p className="text-sm text-muted-foreground">
                Aluno: <span className="font-medium">{student.name}</span>
              </p>
            </div>

            <StatusBanner status={version.status} />

            {version.status === "failed" && (
              <FailureBlock
                errorMessage={version.errorMessage}
                onDiscard={() => router.delete(updatePath)}
                studentHref={`/students/${student.id}`}
              />
            )}

            {version.status === "completed" && version.readOnly && (
              <ReadOnlyVersion
                version={version}
                student={student}
              />
            )}

            {version.status === "completed" && !version.readOnly && (
              <Form method="patch" action={updatePath} className="flex flex-col gap-6">
                {({ processing, errors }) => (
                  <>
                    <section className="flex flex-col gap-2">
                      <label htmlFor="body_md" className="text-sm font-medium">
                        Plano (markdown)
                      </label>
                      <Textarea
                        id="body_md"
                        name="body_md"
                        defaultValue={version.bodyMd}
                        rows={10}
                        className="min-h-48 font-mono text-sm"
                      />
                      {errors.body_md && (
                        <p className="text-sm text-destructive">
                          {errors.body_md.join(", ")}
                        </p>
                      )}
                    </section>

                    <section className="flex flex-col gap-3">
                      <h2 className="text-lg font-medium">Treinos</h2>
                      {version.workouts.map((w, i) => (
                        <fieldset
                          key={w.id}
                          className="flex flex-col gap-2 rounded-xl border bg-muted/20 p-4"
                        >
                          <input
                            type="hidden"
                            name={`workouts[${i}][id]`}
                            value={w.id}
                          />
                          <label className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                            Nome
                          </label>
                          <Input
                            name={`workouts[${i}][name]`}
                            defaultValue={w.name}
                          />
                          <label className="mt-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                            Conteúdo (markdown)
                          </label>
                          <Textarea
                            name={`workouts[${i}][content_md]`}
                            defaultValue={w.contentMd}
                            rows={8}
                            className="font-mono text-sm"
                          />
                        </fieldset>
                      ))}
                    </section>

                    <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
                      <Button
                        type="button"
                        variant="outline"
                        className="h-11 sm:h-10"
                        onClick={() => {
                          if (confirm("Descartar esta versão?")) {
                            router.delete(updatePath)
                          }
                        }}
                        disabled={processing}
                      >
                        Descartar
                      </Button>
                      <Button
                        type="submit"
                        variant="outline"
                        className="h-11 sm:h-10"
                        disabled={processing}
                      >
                        {processing ? "Salvando..." : "Salvar alterações"}
                      </Button>
                      <Button
                        type="button"
                        className="h-11 sm:h-10"
                        onClick={() => router.post(promotePath)}
                        disabled={processing}
                      >
                        Salvar como ativa
                      </Button>
                    </div>
                  </>
                )}
              </Form>
            )}
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}

function ReadOnlyVersion({
  version,
  student,
}: {
  version: Version
  student: Student
}) {
  return (
    <div className="flex flex-col gap-6">
      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Plano</h2>
        <Markdown content={version.bodyMd} placeholder="Plano sem conteúdo." />
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-medium">Treinos</h2>
        {version.workouts.map((w) => (
          <article
            key={w.id}
            className="flex flex-col gap-2 rounded-xl border bg-muted/20 p-4"
          >
            <h3 className="text-sm font-semibold uppercase tracking-wide">
              Treino {w.name}
            </h3>
            <Markdown content={w.contentMd} placeholder="Sem conteúdo." />
          </article>
        ))}
        {version.workouts.length === 0 && (
          <p className="text-sm text-muted-foreground">
            Nenhum treino registrado.
          </p>
        )}
      </section>

      <div className="flex justify-start">
        <Button asChild variant="outline" className="h-11 sm:h-10">
          <Link
            href={`/students/${student.id}/periodizations/${version.periodizationId}`}
          >
            Voltar à periodização
          </Link>
        </Button>
      </div>
    </div>
  )
}

function Markdown({
  content,
  placeholder,
}: {
  content: string
  placeholder: string
}) {
  const trimmed = content.trim()
  if (trimmed.length === 0) {
    return (
      <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
        {placeholder}
      </p>
    )
  }
  return (
    <pre className="whitespace-pre-wrap rounded-xl border bg-muted/30 p-4 font-sans text-sm leading-relaxed">
      {content}
    </pre>
  )
}

function StatusBanner({ status }: { status: Version["status"] }) {
  const messages: Record<Version["status"], string> = {
    pending: "Aguardando início da geração...",
    generating: "Gerando periodização com IA...",
    completed: "Periodização gerada. Revise antes de salvar.",
    failed: "Algo deu errado.",
  }
  const showSpinner = status === "pending" || status === "generating"
  if (status === "failed") return null

  return (
    <div className="flex items-center gap-3 rounded-xl border bg-muted/30 p-4 text-sm">
      {showSpinner && (
        <Loader2Icon
          className="size-5 shrink-0 animate-spin text-muted-foreground"
          aria-hidden
        />
      )}
      <span>{messages[status]}</span>
    </div>
  )
}

function FailureBlock({
  errorMessage,
  onDiscard,
  studentHref,
}: {
  errorMessage: string | null
  onDiscard: () => void
  studentHref: string
}) {
  return (
    <div className="flex flex-col gap-3 rounded-xl border border-destructive/30 bg-destructive/5 p-4">
      <p className="text-sm">
        <span className="font-medium">Falha:</span>{" "}
        {errorMessage ?? "Erro desconhecido."}
      </p>
      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button asChild variant="outline" className="h-11 sm:h-10">
          <Link href={studentHref}>Voltar ao aluno</Link>
        </Button>
        <Button type="button" onClick={onDiscard} className="h-11 sm:h-10">
          Descartar versão
        </Button>
      </div>
    </div>
  )
}
