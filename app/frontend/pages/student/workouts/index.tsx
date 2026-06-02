import { Head } from "@inertiajs/react"
import { ChevronDown, DumbbellIcon, Sparkles } from "lucide-react"
import { motion, type Variants } from "motion/react"

import { BlocksRenderer, type Block } from "@/components/blocks-renderer"
import { BrandMonogram } from "@/components/brand"
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible"
import { cn } from "@/lib/utils"

type Workout = {
  id: string
  name: string
  position: number
  blocks: Block[]
}

type Props = {
  workouts: Workout[]
}

const section: Variants = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0 },
}

export default function StudentWorkouts({ workouts }: Props) {
  const hasPlan = workouts.length > 0

  return (
    <>
      <Head title="Treinos" />
      <div className="mx-auto w-full max-w-md">
        <Header count={workouts.length} />

        <motion.div
          className="space-y-3 px-4 mt-3"
          initial="hidden"
          animate="show"
          transition={{ staggerChildren: 0.07, delayChildren: 0.1 }}
        >
          {hasPlan ? (
            workouts.map((workout) => (
              <motion.div
                key={workout.id}
                variants={section}
                transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
              >
                <WorkoutCard workout={workout} />
              </motion.div>
            ))
          ) : (
            <motion.div variants={section} transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}>
              <EmptyState />
            </motion.div>
          )}
        </motion.div>
      </div>
    </>
  )
}

function Header({ count }: { count: number }) {
  return (
    <section className="relative overflow-hidden rounded-b-[2rem] bg-brand px-6 pb-12 pt-[calc(env(safe-area-inset-top)+1.75rem)] text-brand-foreground">
      <BrandMonogram
        title=""
        className="pointer-events-none absolute -top-10 -right-8 h-52 w-52 text-white/10"
      />
      <motion.p
        className="text-sm font-medium text-brand-foreground/85"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: "easeOut" }}
      >
        Sua periodização
      </motion.p>
      <motion.h1
        className="mt-1.5 font-display text-[2.1rem] font-extrabold uppercase leading-[1.04] tracking-tight"
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.08, ease: [0.16, 1, 0.3, 1] }}
      >
        Treinos
      </motion.h1>
      {count > 0 && (
        <motion.p
          className="mt-2 text-sm text-brand-foreground/85"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.4, delay: 0.16 }}
        >
          {count} {count === 1 ? "treino" : "treinos"} no seu plano
        </motion.p>
      )}
    </section>
  )
}

function WorkoutCard({ workout }: { workout: Workout }) {
  return (
    <Collapsible className="overflow-hidden rounded-2xl border bg-card shadow-lg shadow-brand/5">
      <CollapsibleTrigger className="group flex w-full items-center gap-3 p-5 text-left">
        <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-brand/10 text-brand">
          <DumbbellIcon className="size-[1.15rem]" />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block font-display text-xl font-extrabold tracking-tight">
            {workout.name}
          </span>
        </span>
        <ChevronDown className="size-5 shrink-0 text-muted-foreground transition-transform duration-200 group-data-[state=open]:rotate-180" />
      </CollapsibleTrigger>
      <CollapsibleContent>
        <div className="border-t px-5 pb-5 pt-4">
          <BlocksRenderer
            blocks={workout.blocks}
            variant="student"
            emptyPlaceholder="Treino sem conteúdo."
          />
        </div>
      </CollapsibleContent>
    </Collapsible>
  )
}

function EmptyState() {
  return (
    <div className={cn("rounded-2xl border bg-card p-5 shadow-lg shadow-brand/5")}>
      <div className="flex items-start gap-3">
        <div className="grid size-10 shrink-0 place-items-center rounded-xl bg-accent text-accent-foreground">
          <Sparkles className="size-5" />
        </div>
        <div>
          <p className="font-heading font-semibold">Seu plano está chegando</p>
          <p className="mt-0.5 text-sm text-muted-foreground">
            Seu treinador está montando sua periodização. Volte em breve para ver seus treinos
            aqui.
          </p>
        </div>
      </div>
    </div>
  )
}
