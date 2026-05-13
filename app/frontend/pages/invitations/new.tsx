import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = { emailAddress?: string }

export default function NewInvitation({ emailAddress }: Props) {
  const { errors } = usePage().props
  const form = useForm({
    email_address: emailAddress ?? "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post("/invitations")
  }

  return (
    <>
      <Head title="Novo convite" />
      <div className="flex min-h-screen items-center justify-center bg-muted/40 p-4">
        <form
          onSubmit={submit}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
          <div className="space-y-1">
            <h1 className="text-xl font-semibold">Novo convite</h1>
            <p className="text-sm text-muted-foreground">
              Convide alguém para fazer parte da sua organização.
            </p>
          </div>

          <div className="space-y-2">
            <Input
              type="email"
              placeholder="E-mail"
              autoComplete="email"
              value={form.data.email_address}
              onChange={(e) => form.setData("email_address", e.target.value)}
              required
              autoFocus
            />
            {errors.emailAddress?.[0] && (
              <p className="text-sm text-destructive">{errors.emailAddress[0]}</p>
            )}
          </div>

          <Button type="submit" disabled={form.processing} className="w-full">
            Enviar convite
          </Button>

          <div className="text-sm text-muted-foreground">
            <Link href="/organization" className="underline">
              Voltar para Organização
            </Link>
          </div>
        </form>
      </div>
    </>
  )
}
