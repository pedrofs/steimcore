import { Head, useForm, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = {
  token: string
  emailAddress: string
  organizationName: string
}

export default function EditInvitationAcceptance({
  token,
  emailAddress,
  organizationName,
}: Props) {
  const { errors, flash } = usePage().props
  const form = useForm({
    password: "",
    password_confirmation: "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.put(`/invitation_acceptances/${token}`)
  }

  return (
    <>
      <Head title="Crie sua senha" />
      <div className="flex min-h-screen items-center justify-center bg-muted/40 p-4">
        <form
          onSubmit={submit}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
          <div className="space-y-1">
            <h1 className="text-xl font-semibold">Crie sua senha</h1>
            <p className="text-sm text-muted-foreground">
              Você foi convidado(a) para o <strong>{organizationName}</strong> como{" "}
              <strong>{emailAddress}</strong>.
            </p>
          </div>

          {errors.emailAddress?.[0] && (
            <p className="text-sm text-destructive">{errors.emailAddress[0]}</p>
          )}

          <div className="space-y-2">
            <Input
              type="password"
              placeholder="Senha"
              autoComplete="new-password"
              value={form.data.password}
              onChange={(e) => form.setData("password", e.target.value)}
              required
              autoFocus
            />
            {errors.password?.[0] && (
              <p className="text-sm text-destructive">{errors.password[0]}</p>
            )}
          </div>

          <div className="space-y-2">
            <Input
              type="password"
              placeholder="Confirmar senha"
              autoComplete="new-password"
              value={form.data.password_confirmation}
              onChange={(e) =>
                form.setData("password_confirmation", e.target.value)
              }
              required
            />
            {errors.passwordConfirmation?.[0] && (
              <p className="text-sm text-destructive">
                {errors.passwordConfirmation[0]}
              </p>
            )}
          </div>

          {flash.alert && (
            <p className="text-sm text-destructive">{flash.alert}</p>
          )}

          <Button type="submit" disabled={form.processing} className="w-full">
            Criar conta
          </Button>
        </form>
      </div>
    </>
  )
}
