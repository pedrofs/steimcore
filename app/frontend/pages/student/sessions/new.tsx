import { Link, useForm, usePage } from "@inertiajs/react"

import { AuthShell } from "@/components/auth-shell"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = { emailAddress?: string }

export default function NewStudentSession({ emailAddress }: Props) {
  const { errors, flash } = usePage().props
  const form = useForm({
    email_address: emailAddress ?? "",
    password: "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post("/student/session")
  }

  return (
    <AuthShell
      title="Entrar"
      heading="Entrar como aluno"
      subheading="Acesse seus treinos e progresso"
      footer={
        <>
          É personal?{" "}
          <Link
            href="/session/new"
            className="font-medium text-foreground underline underline-offset-4"
          >
            Entrar como personal
          </Link>
        </>
      }
    >
      <form onSubmit={submit} className="space-y-4">
        {flash.notice && (
          <p className="text-sm text-muted-foreground">{flash.notice}</p>
        )}

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

        <div className="space-y-2">
          <Input
            type="password"
            placeholder="Senha"
            autoComplete="current-password"
            value={form.data.password}
            onChange={(e) => form.setData("password", e.target.value)}
            required
          />
          {errors.password?.[0] && (
            <p className="text-sm text-destructive">{errors.password[0]}</p>
          )}
        </div>

        {(errors.base?.[0] || flash.alert) && (
          <p className="text-sm text-destructive">
            {errors.base?.[0] ?? flash.alert}
          </p>
        )}

        <Button type="submit" disabled={form.processing} className="w-full">
          Entrar
        </Button>

        <div className="flex justify-end text-sm text-muted-foreground">
          <Link
            href="/student/passwords/new"
            className="underline underline-offset-4"
          >
            Esqueci minha senha
          </Link>
        </div>
      </form>
    </AuthShell>
  )
}
