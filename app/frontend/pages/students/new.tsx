import { Form, Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

export default function New() {
  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Cadastre o aluno apenas com o nome agora. Você pode preencher os
          outros campos depois.
        </p>
      </PageHeader>

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
    </>
  )
}
