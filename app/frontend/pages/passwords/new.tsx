import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = { email_address?: string }

export default function NewPassword({ email_address }: Props) {
  const { errors } = usePage().props
  const form = useForm({
    email_address: email_address ?? "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post("/passwords")
  }

  return (
    <>
      <Head title="Redefinir senha" />
      <div className="flex min-h-screen items-center justify-center bg-muted/40 p-4">
        <form
          onSubmit={submit}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
          <div className="space-y-1">
            <h1 className="text-xl font-semibold">Redefina sua senha</h1>
            <p className="text-sm text-muted-foreground">
              Vamos te enviar um e-mail com um link para criar uma nova senha.
            </p>
          </div>

          <div className="space-y-2">
            <Input
              type="email"
              placeholder="E-mail"
              autoComplete="username"
              value={form.data.email_address}
              onChange={(e) => form.setData("email_address", e.target.value)}
              required
              autoFocus
            />
            {errors.email_address?.[0] && (
              <p className="text-sm text-destructive">{errors.email_address[0]}</p>
            )}
          </div>

          <Button type="submit" disabled={form.processing} className="w-full">
            Enviar instruções
          </Button>

          <div className="text-sm text-muted-foreground">
            <Link href="/session/new" className="underline">
              Voltar para o login
            </Link>
          </div>
        </form>
      </div>
    </>
  )
}
