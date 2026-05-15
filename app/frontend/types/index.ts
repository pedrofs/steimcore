export type FlashData = {
  notice?: string
  alert?: string
}

export type CurrentUser = {
  id: number
  email: string
}

export type CurrentOrganization = {
  id: string
  name: string
}

export type Breadcrumb = {
  label: string
  path: string
}

export type SharedProps = {
  currentUser: CurrentUser | null
  currentOrganization: CurrentOrganization | null
  flash: FlashData
  title: string | null
  breadcrumbs: Breadcrumb[]
  activeSessionCount: number
}

export type DashboardTag = "plan_needs_action" | "no_plan" | "anamnesis_pending"

export type DashboardCounts = {
  planNeedsAction: number
  noPlan: number
  anamnesisPending: number
}

export type DashboardRow = {
  student: { id: string; name: string }
  tags: DashboardTag[]
  primaryTag: DashboardTag
}

export type DashboardQueue = {
  counts: DashboardCounts
  rows: DashboardRow[]
}
