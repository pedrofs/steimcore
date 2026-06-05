import { Link, router } from "@inertiajs/react"
import { Trash2Icon } from "lucide-react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"

type TemplateSummary = {
  id: string
  name: string
  description: string | null
}

type Props = {
  templates: TemplateSummary[]
}

export default function Index({ templates }: Props) {
  const isEmpty = templates.length === 0

  return (
    <>
      <PageHeader>
        <p className="text-sm text-muted-foreground">
          Modelos de periodização reutilizáveis da sua organização. Salve um
          plano como modelo a partir da revisão de uma periodização.
        </p>
      </PageHeader>

      {isEmpty ? (
        <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
          Nenhum modelo ainda. Ao revisar uma periodização, use "Salvar como
          modelo" para guardar um plano reutilizável aqui.
        </p>
      ) : (
        <ul className="flex flex-col gap-3">
          {templates.map((template) => (
            <li key={template.id}>
              <div className="flex items-center justify-between gap-3 rounded-xl border bg-card p-4">
                <Link
                  href={`/periodization_templates/${template.id}`}
                  className="flex min-w-0 flex-1 flex-col gap-0.5"
                >
                  <span className="truncate font-medium">{template.name}</span>
                  {template.description && (
                    <span className="truncate text-sm text-muted-foreground">
                      {template.description}
                    </span>
                  )}
                </Link>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="shrink-0 text-muted-foreground hover:text-destructive"
                  aria-label={`Excluir ${template.name}`}
                  onClick={() => {
                    if (confirm(`Excluir o modelo "${template.name}"?`)) {
                      router.delete(`/periodization_templates/${template.id}`)
                    }
                  }}
                >
                  <Trash2Icon className="size-4" />
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}
