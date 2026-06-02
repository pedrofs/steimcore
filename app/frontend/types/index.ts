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

export type Features = {
  studentInvites: boolean
}

export type SharedProps = {
  currentUser: CurrentUser | null
  currentOrganization: CurrentOrganization | null
  flash: FlashData
  title: string | null
  breadcrumbs: Breadcrumb[]
  activeSessionCount: number
  features: Features
  canSwitchProfile?: boolean
  unseenMedalsCount?: number
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
