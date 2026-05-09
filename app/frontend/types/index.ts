export type FlashData = {
  notice?: string
  alert?: string
}

export type CurrentUser = {
  id: number
  email: string
}

export type Breadcrumb = {
  label: string
  path: string
}

export type SharedProps = {
  currentUser: CurrentUser | null
  flash: FlashData
  title: string | null
  breadcrumbs: Breadcrumb[]
}
