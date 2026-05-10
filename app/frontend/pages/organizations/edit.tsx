import { Form, Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"

type Organization = {
  id: string
  name: string
  equipmentListMd: string
}

type Props = {
  organization: Organization
}

export default function Edit({ organization }: Props) {
  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">{organization.name}</p>
      </PageHeader>

      <Form
        method="patch"
        action="/organization"
        className="flex flex-col gap-4"
      >
        {({ errors, processing }) => (
          <>
            <div className="flex flex-col gap-2">
              <Label htmlFor="equipment_list_md">
                Equipamentos disponíveis
              </Label>
              <p className="text-sm text-muted-foreground">
                Liste os equipamentos da academia em markdown. Esse texto
                é usado para gerar as periodizações.
              </p>
              <Textarea
                id="equipment_list_md"
                name="organization[equipment_list_md]"
                defaultValue={organization.equipmentListMd}
                rows={14}
                className="min-h-64 font-mono text-sm"
                placeholder="- 2 leg presses&#10;- halteres 1-30kg&#10;- barras olímpicas"
              />
              {errors.equipmentListMd && (
                <p className="text-sm text-destructive">
                  {errors.equipmentListMd.join(", ")}
                </p>
              )}
            </div>

            <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
              <Button asChild variant="outline" className="h-11 sm:h-10">
                <Link href="/organization">Cancelar</Link>
              </Button>
              <Button
                type="submit"
                disabled={processing}
                className="h-11 sm:h-10"
              >
                {processing ? "Salvando..." : "Salvar"}
              </Button>
            </div>
          </>
        )}
      </Form>
    </>
  )
}
