import { Head, useForm, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Props = { token: string }

export default function EditPassword({ token }: Props) {
  const { errors, flash } = usePage().props
  const form = useForm({
    password: "",
    password_confirmation: "",
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.put(`/passwords/${token}`)
  }

  return (
    <>
      <Head title="Set new password" />
      <div className="flex min-h-screen items-center justify-center bg-muted/40 p-4">
        <form
          onSubmit={submit}
          className="w-full max-w-sm space-y-4 rounded-lg border bg-background p-6 shadow-sm"
        >
          <h1 className="text-xl font-semibold">Set a new password</h1>

          <div className="space-y-2">
            <Input
              type="password"
              placeholder="New password"
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
              placeholder="Confirm new password"
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

          {flash.alert && (
            <p className="text-sm text-destructive">{flash.alert}</p>
          )}

          <Button type="submit" disabled={form.processing} className="w-full">
            Update password
          </Button>
        </form>
      </div>
    </>
  )
}
