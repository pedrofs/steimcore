import { usePage } from "@inertiajs/react"
import { type ReactNode } from "react"

type PageHeaderProps = {
  actions?: ReactNode
  children?: ReactNode
}

export function PageHeader({ actions, children }: PageHeaderProps) {
  const { props } = usePage()
  const title = props.title

  if (!title && !children && !actions) return null

  return (
    <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex flex-col gap-1">
        {title && (
          <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
            {title}
          </h1>
        )}
        {children}
      </div>
      {actions && (
        <div className="flex flex-col gap-2 sm:flex-row">{actions}</div>
      )}
    </div>
  )
}
