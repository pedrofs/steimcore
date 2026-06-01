import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { motion } from "motion/react"

import { BrandLockup } from "@/components/brand"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = { emailAddress?: string }

export default function NewStudentPassword({ emailAddress }: Props) {
  const { errors, flash } = usePage().props
  const form = useForm({
    email_address: emailAddress ?? "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post("/student/passwords")
  }

  return (
    <>
      <Head title="Redefinir senha" />
      <div className="flex min-h-dvh flex-col items-center justify-center gap-6 bg-muted/40 p-4">
        <BrandLockup size="lg" animate />
        <motion.form
          onSubmit={submit}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
          <div className="space-y-1">
            <h1 className="text-xl font-semibold">Redefina sua senha</h1>
            <p className="text-sm text-muted-foreground">
              Vamos te enviar um e-mail com um link para criar uma nova senha.
            </p>
          </div>

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
            {errors.emailAddress?.[0] && (
              <p className="text-sm text-destructive">{errors.emailAddress[0]}</p>
            )}
          </div>

          <Button type="submit" disabled={form.processing} className="w-full">
            Enviar instruções
          </Button>

          <div className="flex justify-end text-sm text-muted-foreground">
            <Link href="/student/session/new" className="underline">
              Voltar para o login
            </Link>
          </div>
        </motion.form>
      </div>
    </>
  )
}
