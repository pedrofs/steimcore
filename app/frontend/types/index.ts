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
  canSwitchProfile?: boolean
}

export type DashboardTag =
  | "plan_needs_action"
  | "periodization_overdue"
  | "periodization_due"
  | "inactive"
  | "no_plan"
  | "anamnesis_pending"

export type DashboardCounts = {
  planNeedsAction: number
  periodizationOverdue: number
  periodizationDue: number
  inactive: number
  noPlan: number
  anamnesisPending: number
}

export type DashboardRow = {
  student: { id: string; name: string }
  tags: DashboardTag[]
  primaryTag: DashboardTag
  sessionsRemaining?: number
}

export type DashboardQueue = {
  counts: DashboardCounts
  rows: DashboardRow[]
}

export type PrintQueueRow = {
  student: { id: string; name: string }
  periodization: { id: string }
  version: { id: string; createdAt: string }
}

export type PrintQueue = {
  count: number
  rows: PrintQueueRow[]
}
