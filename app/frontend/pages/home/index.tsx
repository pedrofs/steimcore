import { usePage } from "@inertiajs/react"

import { PageHeader } from "@/components/page-header"

export default function Home() {
  const { props } = usePage()

  return (
    <>
      <PageHeader />

      <p>Hello, {props.currentUser?.email}</p>

      <div className="grid auto-rows-min gap-4 md:grid-cols-3">
        <div className="aspect-video rounded-xl bg-muted/50" />
        <div className="aspect-video rounded-xl bg-muted/50" />
        <div className="aspect-video rounded-xl bg-muted/50" />
      </div>
      <div className="min-h-screen flex-1 rounded-xl bg-muted/50 md:min-h-min" />
    </>
  )
}
