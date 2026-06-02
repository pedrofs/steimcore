import { Link } from "@inertiajs/react"
import { motion } from "motion/react"
import { ChevronRight, DumbbellIcon, UserIcon } from "lucide-react"

import { AuthShell } from "@/components/auth-shell"

type Choice = {
  href: string
  label: string
  description: string
  icon: typeof DumbbellIcon
}

const CHOICES: Choice[] = [
  {
    href: "/session/new",
    label: "Sou personal",
    description: "Gerencie seus alunos e treinos",
    icon: DumbbellIcon,
  },
  {
    href: "/student/session/new",
    label: "Sou aluno",
    description: "Acesse seus treinos e progresso",
    icon: UserIcon,
  },
]

export default function Landing() {
  return (
    <AuthShell
      heading="Bem-vindo"
      subheading="Como você quer entrar?"
    >
      <div className="space-y-3">
        {CHOICES.map((choice, i) => (
          <motion.div
            key={choice.href}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{
              duration: 0.4,
              delay: 0.4 + i * 0.08,
              ease: [0.16, 1, 0.3, 1],
            }}
          >
            <Link
              href={choice.href}
              className="group flex items-center gap-4 rounded-xl border bg-background p-4 text-left shadow-xs transition-colors outline-none hover:border-brand/40 hover:bg-muted/50 focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
            >
              <span className="flex size-11 shrink-0 items-center justify-center rounded-lg bg-brand/10 text-brand">
                <choice.icon className="size-5" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block font-medium">{choice.label}</span>
                <span className="block text-sm text-muted-foreground">
                  {choice.description}
                </span>
              </span>
              <ChevronRight className="size-5 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
            </Link>
          </motion.div>
        ))}
      </div>
    </AuthShell>
  )
}
