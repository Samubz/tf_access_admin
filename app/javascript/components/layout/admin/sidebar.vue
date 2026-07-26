<script setup lang="ts">
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarRail,
  SidebarTrigger,
} from '@/components/ui/sidebar'
import { Home, GalleryVerticalEnd, Users, UserRound, Settings, Building, Building2, ClipboardList, CalendarDays } from 'lucide-vue-next';
import { Link } from '@inertiajs/vue3';
import NavUser from '@/components/admin/user/nav/NavUser.vue'
import { useI18n } from 'vue-i18n'
import { usePage } from '@inertiajs/vue3'
import { FeatureItem } from '@/types/auth'
import type { OperationalCapabilities } from '@/types/capabilities'
const { t } = useI18n()
const page = usePage()
const features = page.props.auth.features as FeatureItem[]
const capabilities = page.props.capabilities as OperationalCapabilities

const getFeatureIcon = (key: string) => {
  switch (key) {
    case 'home':
      return Home
    case 'users':
      return Users
    case 'people':
      return UserRound
    case 'organizations':
        return Building
    case 'residential_properties':
      return Building2
    case 'organization_settings':
      return Settings
    case 'settings':
        return Settings
  }
  return null
}
</script>

<template>
  <SidebarProvider>
    <Sidebar>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg">
              <div class="flex aspect-square size-8 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
                <GalleryVerticalEnd class="size-4" />
              </div>
              <div class="grid flex-1 text-left text-sm leading-tight">
                <span class="truncate font-semibold capitalize">{{ t('name') }}</span>
                <span class="truncate text-xs capitalize">{{ t('description') }}</span>
              </div>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>{{ t('admin.sidebar.platform') }}</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>

              <SidebarMenuItem v-for="feature in features" :key="feature.key">
                <SidebarMenuButton as-child>
                  <Link :href="feature.url">
                    <component :is="getFeatureIcon(feature.key)" />
                    <span>{{ t(`admin.sidebar.${feature.key}`) }}</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        <!-- Operational Roles Management — shown only if user has manage_staff_assignments capability -->
        <SidebarGroup v-if="capabilities?.manage_staff_assignments">
          <SidebarGroupLabel>{{ t('admin.sidebar.operations') }}</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              <SidebarMenuItem>
                <SidebarMenuButton as-child>
                  <Link href="/admin/operational_roles">
                    <Users class="h-4 w-4" />
                    <span>{{ t('admin.sidebar.operational_roles') }}</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        <!-- Concierge operational visits — view_authorized_visits capability -->
        <SidebarGroup v-if="capabilities?.view_authorized_visits">
          <SidebarGroupLabel>{{ t('admin.sidebar.concierge') }}</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              <SidebarMenuItem>
                <SidebarMenuButton as-child>
                  <Link href="/concierge/visits">
                    <ClipboardList class="h-4 w-4" />
                    <span>{{ t('admin.sidebar.authorized_visits') }}</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        <!-- Admin visit management — manage_visits / view_visits capability -->
        <SidebarGroup v-if="capabilities?.manage_visits || capabilities?.view_visits">
          <SidebarGroupLabel>{{ t('admin.sidebar.visits') }}</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              <SidebarMenuItem>
                <SidebarMenuButton as-child>
                  <Link href="/admin/visits">
                    <CalendarDays class="h-4 w-4" />
                    <span>{{ t('admin.sidebar.manage_visits') }}</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
    <SidebarInset>
      <header class="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-[[data-collapsible=icon]]/sidebar-wrapper:h-12">
        <div class="flex items-center gap-2 px-4">
          <SidebarTrigger class="-ml-1" />
        </div>
      </header>
      <div class="flex flex-1 flex-col gap-4 p-4 pt-0">
        <slot />
      </div>
    </SidebarInset>
  </SidebarProvider>
</template>
