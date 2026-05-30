import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { motion } from "motion/react"

import { BrandLockup } from "@/components/brand"
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
    <>
      <Head title="Entrar" />
      <div className="flex min-h-dvh flex-col items-center justify-center gap-6 bg-muted/40 p-4">
        <BrandLockup size="lg" showTagline animate />
        <motion.form
          onSubmit={submit}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
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
            <Link href="/student/passwords/new" className="underline">
              Esqueci minha senha
            </Link>
          </div>
        </motion.form>
      </div>
    </>
  )
}
