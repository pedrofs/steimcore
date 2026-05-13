import { Head, Link, useForm, usePage } from "@inertiajs/react"

import { BrandLockup } from "@/components/brand"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = { email_address?: string }

export default function NewSession({ email_address }: Props) {
  const { errors, flash } = usePage().props
  const form = useForm({
    email_address: email_address ?? "",
    password: "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post("/session")
  }

  return (
    <>
      <Head title="Sign in" />
      <div className="flex min-h-dvh flex-col items-center justify-center gap-6 bg-muted/40 p-4">
        <BrandLockup size="lg" showTagline animate />
        <form
          onSubmit={submit}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
          {flash.notice && (
            <p className="text-sm text-muted-foreground">{flash.notice}</p>
          )}

          <div className="space-y-2">
            <Input
              type="email"
              placeholder="Email address"
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
              placeholder="Password"
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
            Sign in
          </Button>

          <div className="flex justify-end text-sm text-muted-foreground">
            <Link href="/passwords/new" className="underline">
              Forgot password?
            </Link>
          </div>
        </form>
      </div>
    </>
  )
}
