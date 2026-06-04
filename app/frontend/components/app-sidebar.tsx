import * as React from "react"
import { Link, router, usePage } from "@inertiajs/react"
import { Activity, BarChart3, ChevronsUpDown, DumbbellIcon, HomeIcon, LibraryBig, LogOut, UsersIcon } from "lucide-react"

import { BrandLockup, BrandMark } from "@/components/brand"
import { InstallAppMenuItem } from "@/components/install-app"

import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
  useSidebar,
} from "@/components/ui/sidebar"

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const { url, props: pageProps } = usePage()
  const { state, isMobile, setOpenMobile } = useSidebar()
  const collapsed = state === "collapsed"
  const closeOnMobile = () => {
    if (isMobile) setOpenMobile(false)
  }
  const user = pageProps.currentUser
  const activeSessionCount = pageProps.activeSessionCount
  const initials = (user?.email ?? "?").slice(0, 2).toUpperCase()

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader className="pt-[env(safe-area-inset-top)]">
        <div
          className={
            collapsed
              ? "flex justify-center px-0 py-1.5"
              : "flex items-center px-2 py-1.5"
          }
        >
          {collapsed ? (
            <BrandMark className="size-7" />
          ) : (
            <BrandLockup size="sm" />
          )}
        </div>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Platform</SidebarGroupLabel>
          <SidebarMenu>
            <SidebarMenuItem>
              <SidebarMenuButton
                asChild
                tooltip="Home"
                isActive={url === "/"}
                className="h-11 md:h-8"
              >
                <Link href="/" onClick={closeOnMobile}>
                  <HomeIcon />
                  <span>Home</span>
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
            <SidebarMenuItem>
              <SidebarMenuButton
                asChild
                tooltip="Pista"
                isActive={url.startsWith("/training_sessions")}
                className="h-11 md:h-8"
              >
                <Link href="/training_sessions" onClick={closeOnMobile}>
                  <Activity />
                  <span>Pista</span>
                  {activeSessionCount > 0 && (
                    <Badge variant="secondary" className="ml-auto">
                      {activeSessionCount}
                    </Badge>
                  )}
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
            <SidebarMenuItem>
              <SidebarMenuButton
                asChild
                tooltip="Alunos"
                isActive={url.startsWith("/students")}
                className="h-11 md:h-8"
              >
                <Link href="/students" onClick={closeOnMobile}>
                  <UsersIcon />
                  <span>Alunos</span>
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
            <SidebarMenuItem>
              <SidebarMenuButton
                asChild
                tooltip="Exercícios"
                isActive={url.startsWith("/exercises")}
                className="h-11 md:h-8"
              >
                <Link href="/exercises" onClick={closeOnMobile}>
                  <LibraryBig />
                  <span>Exercícios</span>
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
            <SidebarMenuItem>
              <SidebarMenuButton
                asChild
                tooltip="Analytics"
                isActive={url.startsWith("/analytics")}
                className="h-11 md:h-8"
              >
                <Link href="/analytics" onClick={closeOnMobile}>
                  <BarChart3 />
                  <span>Analytics</span>
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
            <SidebarMenuItem>
              <SidebarMenuButton
                asChild
                tooltip="Organização"
                isActive={url.startsWith("/organization")}
                className="h-11 md:h-8"
              >
                <Link href="/organization" onClick={closeOnMobile}>
                  <DumbbellIcon />
                  <span>Organização</span>
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter className="pb-[max(0.5rem,env(safe-area-inset-bottom))]">
        {user && (
          <SidebarMenu>
            <SidebarMenuItem>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <SidebarMenuButton
                    size="lg"
                    tooltip={user.email}
                    className="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
                  >
                    <Avatar className="size-8 rounded-lg">
                      <AvatarFallback className="rounded-lg">{initials}</AvatarFallback>
                    </Avatar>
                    <div className="grid flex-1 text-left text-sm leading-tight">
                      <span className="truncate font-medium">{user.email}</span>
                    </div>
                    <ChevronsUpDown className="ml-auto size-4" />
                  </SidebarMenuButton>
                </DropdownMenuTrigger>
                <DropdownMenuContent
                  align="end"
                  side={collapsed ? "right" : "top"}
                  className="w-56"
                >
                  <DropdownMenuLabel className="truncate font-normal">
                    {user.email}
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  <InstallAppMenuItem />
                  <DropdownMenuItem
                    onSelect={() =>
                      router.delete("/session", { preserveScroll: true })
                    }
                  >
                    <LogOut className="mr-2 size-4" />
                    Sign out
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </SidebarMenuItem>
          </SidebarMenu>
        )}
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
