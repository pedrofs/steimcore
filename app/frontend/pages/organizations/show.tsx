import { Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"

type Organization = {
  id: string
  name: string
  equipmentListMd: string
}

type Props = {
  organization: Organization
}

export default function Show({ organization }: Props) {
  const hasEquipment = organization.equipmentListMd.trim().length > 0

  return (
    <>
      <PageHeader
        actions={
          <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
            <Link href="/organization/edit">Editar equipamentos</Link>
          </Button>
        }
      >
        <p className="text-sm text-muted-foreground">{organization.name}</p>
      </PageHeader>

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
    </>
  )
}
