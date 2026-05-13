import { Link, router } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

type Organization = {
  id: string
  name: string
  equipmentListMd: string
}

type Member = {
  id: number
  email: string
  joinedAt: string
  isCurrentUser: boolean
}

type PendingInvitation = {
  id: string
  email: string
  invitedByEmail: string
  invitedAt: string
  expired: boolean
}

type Props = {
  organization: Organization
  members: Member[]
  pendingInvitations: PendingInvitation[]
}

const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
  day: "2-digit",
  month: "short",
  year: "numeric",
})

function formatDate(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ""
  return dateFormatter.format(date)
}

export default function Show({
  organization,
  members,
  pendingInvitations,
}: Props) {
  const hasEquipment = organization.equipmentListMd.trim().length > 0
  const hasPending = pendingInvitations.length > 0

  return (
    <>
      <PageHeader
        actions={
          <Button asChild className="h-11 w-full sm:h-10 sm:w-auto">
            <Link href="/organization/edit">Editar equipamentos</Link>
          </Button>
        }
      >
        <p className="text-sm text-muted-foreground">{organization.name}</p>
      </PageHeader>

      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Membros</h2>
        <ul className="flex flex-col divide-y rounded-xl border bg-card">
          {members.map((member) => (
            <li
              key={member.id}
              className="flex flex-wrap items-center justify-between gap-2 p-4"
            >
              <div className="flex flex-col">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">{member.email}</span>
                  {member.isCurrentUser && (
                    <Badge variant="secondary">Você</Badge>
                  )}
                </div>
                <span className="text-xs text-muted-foreground">
                  Membro desde {formatDate(member.joinedAt)}
                </span>
              </div>
            </li>
          ))}
        </ul>
      </section>

      <section className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-lg font-medium">Convites pendentes</h2>
          <Button asChild variant="outline" size="sm">
            <Link href="/invitations/new">Novo convite</Link>
          </Button>
        </div>

        {hasPending ? (
          <ul className="flex flex-col divide-y rounded-xl border bg-card">
            {pendingInvitations.map((invitation) => (
              <li
                key={invitation.id}
                className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
              >
                <div className="flex flex-col gap-1">
                  <span className="text-sm font-medium">{invitation.email}</span>
                  <span className="text-xs text-muted-foreground">
                    Convidado por {invitation.invitedByEmail} em{" "}
                    {formatDate(invitation.invitedAt)}
                  </span>
                  {invitation.expired && (
                    <span className="text-xs text-destructive">
                      Expirado — reenvie para gerar um novo link
                    </span>
                  )}
                </div>
                <div className="flex flex-row gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() =>
                      router.post(`/invitations/${invitation.id}/delivery`)
                    }
                  >
                    Reenviar
                  </Button>
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button type="button" variant="ghost" size="sm">
                        Revogar
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent size="sm">
                      <AlertDialogHeader>
                        <AlertDialogTitle>Revogar convite?</AlertDialogTitle>
                        <AlertDialogDescription>
                          Tem certeza que deseja revogar este convite? O link
                          enviado para {invitation.email} deixará de funcionar
                          imediatamente.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancelar</AlertDialogCancel>
                        <AlertDialogAction
                          variant="destructive"
                          onClick={() =>
                            router.delete(`/invitations/${invitation.id}`)
                          }
                        >
                          Revogar
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                </div>
              </li>
            ))}
          </ul>
        ) : (
          <div className="flex flex-col items-start gap-3 rounded-xl border border-dashed bg-muted/20 p-6">
            <p className="text-sm font-medium">Nenhum convite pendente.</p>
            <Button asChild size="sm">
              <Link href="/invitations/new">Novo convite</Link>
            </Button>
          </div>
        )}
      </section>

      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Equipamentos disponíveis</h2>
        {hasEquipment ? (
          <pre className="whitespace-pre-wrap rounded-xl border bg-muted/30 p-4 font-sans text-sm leading-relaxed">
            {organization.equipmentListMd}
          </pre>
        ) : (
          <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
            Nenhum equipamento cadastrado ainda. Toque em &quot;Editar
            equipamentos&quot; para adicionar.
          </p>
        )}
      </section>
    </>
  )
}
