import { Form, Head, Link, usePage } from "@inertiajs/react"
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
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Separator } from "@/components/ui/separator"
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar"

export default function New() {
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
            <div>
              {title && (
                <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                  {title}
                </h1>
              )}
              <p className="text-sm text-muted-foreground">
                Cadastre o aluno apenas com o nome agora. Você pode preencher os
                outros campos depois.
              </p>
            </div>

            <Form
              method="post"
              action="/students"
              className="flex flex-col gap-4"
            >
              {({ errors, processing }) => (
                <>
                  <div className="flex flex-col gap-2">
                    <Label htmlFor="name">Nome</Label>
                    <Input
                      id="name"
                      name="student[name]"
                      autoFocus
                      required
                      autoComplete="off"
                      className="h-11"
                    />
                    {errors.name && (
                      <p className="text-sm text-destructive">
                        {errors.name.join(", ")}
                      </p>
                    )}
                  </div>

                  <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
                    <Button asChild variant="outline" className="h-11 sm:h-10">
                      <Link href="/students">Cancelar</Link>
                    </Button>
                    <Button
                      type="submit"
                      disabled={processing}
                      className="h-11 sm:h-10"
                    >
                      {processing ? "Salvando..." : "Cadastrar"}
                    </Button>
                  </div>
                </>
              )}
            </Form>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}
