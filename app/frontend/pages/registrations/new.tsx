import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = { email_address?: string }

export default function NewRegistration({ email_address }: Props) {
  const { errors } = usePage().props
  const form = useForm({
    email_address: email_address ?? "",
    password: "",
    password_confirmation: "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post("/registration")
  }

  return (
    <>
      <Head title="Create account" />
      <div className="flex min-h-screen items-center justify-center bg-muted/40 p-4">
        <form
          onSubmit={submit}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
          <h1 className="text-xl font-semibold">Create your account</h1>

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
              autoComplete="new-password"
              value={form.data.password}
              onChange={(e) => form.setData("password", e.target.value)}
              required
            />
            {errors.password?.[0] && (
              <p className="text-sm text-destructive">{errors.password[0]}</p>
            )}
          </div>

          <div className="space-y-2">
            <Input
              type="password"
              placeholder="Confirm password"
              autoComplete="new-password"
              value={form.data.password_confirmation}
              onChange={(e) =>
                form.setData("password_confirmation", e.target.value)
              }
              required
            />
            {errors.password_confirmation?.[0] && (
              <p className="text-sm text-destructive">
                {errors.password_confirmation[0]}
              </p>
            )}
          </div>

          <Button type="submit" disabled={form.processing} className="w-full">
            Create account
          </Button>

          <div className="text-sm text-muted-foreground">
            Already have an account?{" "}
            <Link href="/session/new" className="underline">
              Sign in
            </Link>
          </div>
        </form>
      </div>
    </>
  )
}
