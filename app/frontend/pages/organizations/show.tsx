import { Head, Link, usePage } from "@inertiajs/react"
import { Fragment } from "react"

import { AppSidebar } from "@/components/app-sidebar"
import { Button } from "@/components/ui/button"
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb"
import { Separator } from "@/components/ui/separator"
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar"

type Organization = {
  id: string
  name: string
  equipmentListMd: string
}

type Props = {
  organization: Organization
}

export default function Show({ organization }: Props) {
  const { props } = usePage()
  const title = props.title
  const breadcrumbs = props.breadcrumbs
  const hasEquipment = organization.equipmentListMd.trim().length > 0

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
              <div>
                {title && (
                  <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                    {title}
                  </h1>
                )}
                <p className="text-sm text-muted-foreground">{organization.name}</p>
              </div>
              <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
                <Link href="/organization/edit">Editar equipamentos</Link>
              </Button>
            </div>

            <section className="flex flex-col gap-2">
              <h2 className="text-lg font-medium">Equipamentos disponíveis</h2>
              {hasEquipment ? (
                <pre className="whitespace-pre-wrap rounded-xl border bg-muted/30 p-4 font-sans text-sm leading-relaxed">
                  {organization.equipmentListMd}
                </pre>
              ) : (
                <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
                  Nenhum equipamento cadastrado ainda. Toque em &quot;Editar
                  equipamentos&quot; para adicionar.
                </p>
              )}
            </section>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}
