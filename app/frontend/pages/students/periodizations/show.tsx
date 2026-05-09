import { Head, Link, router, usePage } from "@inertiajs/react"
import { Fragment } from "react"
import { PencilIcon, WandSparklesIcon } from "lucide-react"

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

type Workout = {
  id: string
  name: string
  position: number
  contentMd: string
}

type CurrentVersion = {
  id: string
  bodyMd: string
  workouts: Workout[]
}

type VersionSummary = {
  id: string
  createdAt: string
  current: boolean
  trainer: { id: string; email: string }
  transcriptExcerpt: string
  path: string
}

type Periodization = {
  id: string
  archived: boolean
  currentVersion: CurrentVersion | null
  versions: VersionSummary[]
}

type Student = { id: string; name: string }

type Props = { student: Student; periodization: Periodization }

export default function ShowPeriodization({ student, periodization }: Props) {
  const { props } = usePage()
  const title = props.title
  const breadcrumbs = props.breadcrumbs
  const version = periodization.currentVersion

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
              {periodization.archived && (
                <span className="inline-flex w-fit items-center rounded-full border border-dashed bg-muted/40 px-2 py-0.5 text-xs text-muted-foreground">
                  Arquivada
                </span>
              )}
            </div>

            {version ? (
              <>
                {!periodization.archived && (
                  <Button
                    type="button"
                    className="h-11 w-full gap-2 sm:h-10 sm:w-auto sm:self-start"
                    onClick={() =>
                      router.post(`/periodizations/${periodization.id}/edit`)
                    }
                  >
                    <WandSparklesIcon className="size-4" />
                    Modificar periodização
                  </Button>
                )}

                <section className="flex flex-col gap-2">
                  <h2 className="text-lg font-medium">Plano</h2>
                  <Markdown
                    content={version.bodyMd}
                    placeholder="Plano sem conteúdo."
                  />
                </section>

                <section className="flex flex-col gap-3">
                  <h2 className="text-lg font-medium">Treinos</h2>
                  <div className="grid grid-cols-1 gap-3">
                    {version.workouts.map((w) => (
                      <article
                        key={w.id}
                        className="flex flex-col gap-2 rounded-xl border bg-muted/20 p-4"
                      >
                        <h3 className="text-sm font-semibold uppercase tracking-wide">
                          Treino {w.name}
                        </h3>
                        <Markdown
                          content={w.contentMd}
                          placeholder="Sem conteúdo."
                        />
                        {!periodization.archived && (
                          <Button
                            type="button"
                            variant="outline"
                            className="mt-2 h-11 w-full gap-2 sm:h-10 sm:w-auto sm:self-end"
                            onClick={() =>
                              router.post(
                                `/periodization_versions/${version.id}/workouts/${w.id}/edit`,
                              )
                            }
                          >
                            <PencilIcon className="size-4" />
                            Editar este treino
                          </Button>
                        )}
                      </article>
                    ))}
                    {version.workouts.length === 0 && (
                      <p className="text-sm text-muted-foreground">
                        Nenhum treino registrado.
                      </p>
                    )}
                  </div>
                </section>
              </>
            ) : (
              <p className="text-sm text-muted-foreground">
                Esta periodização ainda não tem uma versão ativa.
              </p>
            )}

            <VersionHistory versions={periodization.versions} />

            <div className="flex justify-start">
              <Button asChild variant="outline" className="h-11 sm:h-10">
                <Link href={`/students/${student.id}`}>Voltar ao aluno</Link>
              </Button>
            </div>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}

function VersionHistory({ versions }: { versions: VersionSummary[] }) {
  if (versions.length === 0) {
    return null
  }
  const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
  })
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-medium">Histórico de versões</h2>
      <ol className="flex flex-col gap-2">
        {versions.map((v) => (
          <li
            key={v.id}
            className={
              "flex flex-col gap-1 rounded-xl border p-3 " +
              (v.current ? "border-primary bg-primary/5" : "bg-muted/20")
            }
          >
            <div className="flex flex-wrap items-center gap-2 text-sm">
              <span className="font-medium">
                {dateFormatter.format(new Date(v.createdAt))}
              </span>
              <span className="text-muted-foreground">·</span>
              <span className="text-muted-foreground">{v.trainer.email}</span>
              {v.current && (
                <span className="ml-auto rounded-full bg-primary px-2 py-0.5 text-xs font-medium text-primary-foreground">
                  Atual
                </span>
              )}
            </div>
            {v.transcriptExcerpt.length > 0 && (
              <p className="text-sm text-muted-foreground italic">
                "{v.transcriptExcerpt}"
              </p>
            )}
            <div>
              <Link
                href={v.path}
                className="text-sm font-medium text-primary underline-offset-4 hover:underline"
              >
                Ver versão
              </Link>
            </div>
          </li>
        ))}
      </ol>
    </section>
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
