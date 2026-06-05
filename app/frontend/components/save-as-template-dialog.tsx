import { useEffect, useState } from "react"
import { useForm } from "@inertiajs/react"

import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"

type Props = {
  versionId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function SaveAsTemplateDialog({ versionId, open, onOpenChange }: Props) {
  const [name, setName] = useState("")
  const [description, setDescription] = useState("")
  const form = useForm({})

  useEffect(() => {
    if (open) {
      setName("")
      setDescription("")
      form.clearErrors()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  const canSubmit = name.trim().length > 0

  const submit = (event: React.MouseEvent) => {
    event.preventDefault()
    form.transform(() => ({
      periodizationTemplate: { name: name.trim(), description: description.trim() },
    }))
    form.post(`/periodization_versions/${versionId}/template`, {
      preserveScroll: true,
      onSuccess: () => onOpenChange(false),
    })
  }

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Salvar como modelo</AlertDialogTitle>
          <AlertDialogDescription>
            Cria um modelo reutilizável a partir do conteúdo desta periodização.
            O modelo é uma cópia independente — editar este plano depois não o
            altera.
          </AlertDialogDescription>
        </AlertDialogHeader>

        <div className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="template-name">Nome</Label>
            <Input
              id="template-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ex.: Iniciante 3x/semana"
              autoFocus
              maxLength={120}
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="template-description">Descrição (opcional)</Label>
            <Textarea
              id="template-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Ex.: foco hipertrofia, para quem está voltando a treinar"
              rows={2}
            />
          </div>
        </div>

        <AlertDialogFooter>
          <AlertDialogCancel disabled={form.processing}>
            Cancelar
          </AlertDialogCancel>
          <Button onClick={submit} disabled={!canSubmit || form.processing}>
            Salvar modelo
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
