import { Head, router } from "@inertiajs/react"

import { BrandLockup } from "@/components/brand"
import { Button } from "@/components/ui/button"

type StudentProfile = {
  id: string
  name: string
  organizationName: string
}

type Props = {
  students: StudentProfile[]
}

export default function NewStudentProfileSelection({ students }: Props) {
  const choose = (studentId: string) =>
    router.post("/student/profile_selection", { student_id: studentId })

  return (
    <>
      <Head title="Escolher perfil" />
      <div className="flex min-h-dvh flex-col items-center justify-center gap-6 bg-muted/40 p-4">
        <BrandLockup size="lg" />
        <div className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm">
          <div className="space-y-1 text-center">
            <h1 className="text-lg font-semibold">Escolha um perfil</h1>
            <p className="text-sm text-muted-foreground">
              Você treina em mais de uma academia. Selecione qual perfil deseja
              ver.
            </p>
          </div>
          <div className="space-y-2">
            {students.map((student) => (
              <Button
                key={student.id}
                variant="outline"
                className="h-auto w-full flex-col items-start gap-0.5 py-3 text-left"
                onClick={() => choose(student.id)}
              >
                <span className="font-medium">{student.name}</span>
                <span className="text-xs text-muted-foreground">
                  {student.organizationName}
                </span>
              </Button>
            ))}
          </div>
        </div>
      </div>
    </>
  )
}
