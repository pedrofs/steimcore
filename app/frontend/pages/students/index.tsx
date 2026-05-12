import { Link } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import { Button } from "@/components/ui/button"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"

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
  return (
    <>
      <PageHeader
        actions={
          <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
            <Link href="/students/new">Novo aluno</Link>
          </Button>
        }
      />

      {students.length === 0 ? (
        <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
          Nenhum aluno cadastrado ainda. Toque em &quot;Novo aluno&quot;
          para começar.
        </p>
      ) : (
        <>
          <ul className="flex flex-col gap-2 md:hidden">
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

          <div className="hidden rounded-xl border bg-card md:block">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nome</TableHead>
                  <TableHead>Objetivo</TableHead>
                  <TableHead>Frequência semanal</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {students.map((student) => (
                  <TableRow key={student.id}>
                    <TableCell className="font-medium">
                      <Link
                        href={`/students/${student.id}`}
                        className="hover:underline"
                      >
                        {student.name}
                      </Link>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {student.primaryGoal ?? "—"}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {student.weeklyFrequency != null
                        ? `${student.weeklyFrequency}×/semana`
                        : "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </>
      )}
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
