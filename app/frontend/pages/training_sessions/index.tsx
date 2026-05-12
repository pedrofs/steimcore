import { Head, Link } from "@inertiajs/react"
import { PlusIcon, XIcon } from "lucide-react"

import { Button } from "@/components/ui/button"

type TrainingSessionRow = {
  id: string
}

type PickerCandidate = {
  id: string
}

type Props = {
  trainingSessions: TrainingSessionRow[]
  pickerCandidates: PickerCandidate[]
  scope: "trainer" | "org"
}

export default function TrainingSessionsIndex({ trainingSessions }: Props) {
  const isEmpty = trainingSessions.length === 0

  return (
    <>
      <Head title="Sessões ao vivo" />
      <div className="relative flex min-h-screen flex-col bg-background">
        <Link
          href="/"
          aria-label="Fechar"
          className="absolute top-3 left-3 inline-flex size-9 items-center justify-center rounded-full text-muted-foreground hover:bg-muted hover:text-foreground"
        >
          <XIcon className="size-5" />
        </Link>

        {isEmpty && (
          <div className="flex flex-1 items-center justify-center px-6">
            <Button size="lg" className="gap-2" disabled>
              <PlusIcon className="size-5" />
              Adicionar aluno
            </Button>
          </div>
        )}
      </div>
    </>
  )
}
