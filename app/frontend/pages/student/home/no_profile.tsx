import { Head, router } from "@inertiajs/react"

import { BrandLockup } from "@/components/brand"
import { Button } from "@/components/ui/button"

export default function StudentNoProfile() {
  const signOut = () => router.delete("/student/session", { preserveScroll: true })

  return (
    <>
      <Head title="Nenhum perfil disponível" />
      <div className="flex min-h-dvh flex-col items-center justify-center gap-6 bg-muted/40 p-4">
        <BrandLockup size="lg" />
        <div className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 text-center shadow-sm">
          <h1 className="text-lg font-semibold">Nenhum perfil disponível</h1>
          <p className="text-sm text-muted-foreground">
            Sua conta não está vinculada a nenhum perfil de aluno no momento.
            Fale com seu treinador para regularizar seu acesso.
          </p>
          <Button variant="outline" className="w-full" onClick={signOut}>
            Sair
          </Button>
        </div>
      </div>
    </>
  )
}
