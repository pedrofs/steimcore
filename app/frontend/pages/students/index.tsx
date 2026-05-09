import { Head, Link, usePage } from "@inertiajs/react"
import { Fragment } from "react"

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

type StudentSummary = {
  id: string
  name: string
  primaryGoal: string | null
  weeklyFrequency: number | null
}

type Props = {
  students: StudentSummary[]
}

export default function Index({ students }: Props) {
  const { props } = usePage()
  const title = props.title
  const breadcrumbs = props.breadcrumbs

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
            <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              {title && (
                <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                  {title}
                </h1>
              )}
              <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
                <Link href="/students/new">Novo aluno</Link>
              </Button>
            </div>

            {students.length === 0 ? (
              <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
                Nenhum aluno cadastrado ainda. Toque em &quot;Novo aluno&quot;
                para começar.
              </p>
            ) : (
              <ul className="flex flex-col gap-2">
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
            )}
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}

function summaryLine(student: StudentSummary): string {
  const parts: string[] = []
  if (student.primaryGoal) parts.push(student.primaryGoal)
  if (student.weeklyFrequency != null)
    parts.push(`${student.weeklyFrequency}x/semana`)
  return parts.length > 0 ? parts.join(" · ") : "Sem dados estruturados"
}
