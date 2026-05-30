import { Head, Link, router, usePage } from "@inertiajs/react"

import { BrandLockup } from "@/components/brand"
import { Button } from "@/components/ui/button"

type Props = {
  studentName?: string | null
  organizationName?: string | null
}

export default function StudentHome({ studentName, organizationName }: Props) {
  const { canSwitchProfile } = usePage().props
  const signOut = () => router.delete("/student/session", { preserveScroll: true })

  return (
    <>
      <Head title="Início" />
      {canSwitchProfile && (
        <header className="absolute inset-x-0 top-0 flex justify-end p-4">
          <Link
            href="/student/profile_selection/new"
            className="text-sm text-muted-foreground underline"
          >
            Trocar perfil
          </Link>
        </header>
      )}
      <div className="flex min-h-dvh flex-col items-center justify-center gap-6 bg-muted/40 p-4">
        <BrandLockup size="lg" />
        <div className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 text-center shadow-sm">
          {studentName && (
            <h1 className="text-xl font-semibold">{studentName}</h1>
          )}
          {organizationName && (
            <p className="text-sm text-muted-foreground">{organizationName}</p>
          )}
          <Button variant="outline" className="w-full" onClick={signOut}>
            Sair
          </Button>
        </div>
      </div>
    </>
  )
}
