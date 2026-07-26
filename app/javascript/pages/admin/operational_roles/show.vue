<template>
  <div>
    <Header :itemsBreadcrumb="breadcrumbs" :title="role.name" />

    <div class="p-6 space-y-6">
      <div class="rounded-lg border bg-card px-6 py-5 flex items-start justify-between gap-4">
        <div class="space-y-2">
          <div class="flex items-center gap-2 flex-wrap">
            <h2 class="text-xl font-semibold">{{ role.name }}</h2>
            <Badge variant="outline">{{ role.scope_label }}</Badge>
            <Badge class="bg-green-100 text-green-800 border-green-200">{{ t('common.status.active') }}</Badge>
          </div>
          <p class="text-sm text-muted-foreground">{{ role.description }}</p>
          <p class="text-sm text-muted-foreground">
            {{ role.users_count ?? 0 }}
            {{ role.users_count === 1 ? t('admin.operational_roles.show.users_heading') : t('admin.operational_roles.show.users_heading_plural') }}
            · {{ role.capabilities?.length ?? 0 }} {{ t('common.capabilities') }}
          </p>
        </div>
        <Link v-if="permissions.manage && role.assignable" :href="admin_operational_roles_assignments_path()">
          <Button size="sm">
            <UserPlusIcon class="w-4 h-4 mr-1" />
            {{ t('admin.operational_roles.show.assign_persons_button') }}
          </Button>
        </Link>
      </div>

      <div class="border-b">
        <div class="flex gap-4 px-1">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            type="button"
            class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
            :class="activeTab === tab.key ? 'border-primary text-foreground' : 'border-transparent text-muted-foreground'"
            @click="activeTab = tab.key"
          >
            {{ tab.label }}
          </button>
        </div>
      </div>

      <div v-if="activeTab === 'permissions'" class="grid grid-cols-1 lg:grid-cols-[220px_1fr] gap-4">
        <div class="rounded-lg border bg-card p-2 space-y-1">
          <button
            v-for="group in capability_groups"
            :key="group.module_key"
            type="button"
            class="w-full text-left px-3 py-2 rounded-md text-sm"
            :class="selectedModule === group.module_key ? 'bg-muted font-medium' : 'hover:bg-muted/60'"
            @click="selectedModule = group.module_key"
          >
            {{ group.module }}
          </button>
        </div>

        <div v-if="selectedGroup" class="rounded-lg border bg-card">
          <div class="px-6 py-4 border-b">
            <h3 class="font-semibold">{{ selectedGroup.module }}</h3>
          </div>
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b bg-muted/40">
                <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.permission_columns.permission') }}</th>
                <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.permission_columns.description') }}</th>
                <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.permission_columns.access') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="cap in selectedGroup.capabilities" :key="cap.key" class="border-b last:border-0">
                <td class="px-6 py-3 font-medium">{{ cap.label }}</td>
                <td class="px-6 py-3 text-muted-foreground">{{ cap.description }}</td>
                <td class="px-6 py-3">
                  <Badge :class="accessBadgeClass(cap.access)">{{ accessLabel(cap.access) }}</Badge>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-else-if="activeTab === 'users'" class="rounded-lg border bg-card">
        <div class="px-6 py-4 border-b">
          <h3 class="font-semibold">
            {{ role.users_count === 1 ? t('admin.operational_roles.show.users_heading') : t('admin.operational_roles.show.users_heading_plural') }}
            ({{ role.users_count ?? 0 }})
          </h3>
        </div>
        <div v-if="users.length === 0" class="px-6 py-12 text-center text-muted-foreground text-sm">
          {{ t('admin.operational_roles.show.no_assigned_users') }}
        </div>
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="border-b bg-muted/40">
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.table_headers.person') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.table_headers.user') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.table_headers.scope') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.table_headers.status') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.table_headers.from') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.show.table_headers.to') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="u in users" :key="u.assignment_id ?? u.person_id" class="border-b last:border-0 hover:bg-muted/20">
              <td class="px-6 py-3">{{ u.person_name ?? '—' }}</td>
              <td class="px-6 py-3 text-muted-foreground">{{ u.user_email ?? '—' }}</td>
              <td class="px-6 py-3 text-muted-foreground">{{ u.scope_label ?? '—' }}</td>
              <td class="px-6 py-3">
                <Badge :class="u.status === 'active' ? 'bg-green-100 text-green-800 border-green-200' : ''" variant="outline">
                  {{ u.status === 'active' ? t('common.status.active') : t('common.status.inactive') }}
                </Badge>
              </td>
              <td class="px-6 py-3 text-muted-foreground">{{ u.starts_at ?? '—' }}</td>
              <td class="px-6 py-3 text-muted-foreground">{{ u.ends_at ?? '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-else class="rounded-lg border bg-card px-6 py-5 space-y-2">
        <h3 class="font-semibold">{{ t('admin.operational_roles.show.scope_heading') }}</h3>
        <p class="text-sm text-muted-foreground">
          {{ role.scope === 'organization'
            ? t('admin.operational_roles.show.scope_description_organization')
            : t('admin.operational_roles.show.scope_description_property') }}
        </p>
        <Badge variant="outline">{{ role.scope_label }}</Badge>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue"
import { Link } from "@inertiajs/vue3"
import { useI18n } from "vue-i18n"
import Header from "@/components/admin/layout/Header.vue"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { UserPlusIcon } from "lucide-vue-next"
import { admin_operational_roles_assignments_path, admin_operational_roles_path } from "@/routes"
import type { CapabilityModuleGroup, RoleUser, OperationalRoleDefinition } from "@/types/operational_roles"

const { t } = useI18n()

const props = defineProps<{
  role: OperationalRoleDefinition & { capabilities: string[] }
  users: RoleUser[]
  capability_groups: CapabilityModuleGroup[]
  permissions: { manage: boolean }
}>()

const activeTab = ref<"permissions" | "users" | "scope">("permissions")
const selectedModule = ref(props.capability_groups[0]?.module_key ?? "")

const tabs = computed(() => [
  { key: "permissions" as const, label: t('admin.operational_roles.show.permissions_tab') },
  { key: "users" as const, label: t('admin.operational_roles.show.users_tab') },
  { key: "scope" as const, label: t('admin.operational_roles.show.scope_tab') }
])

const selectedGroup = computed(() =>
  props.capability_groups.find((group) => group.module_key === selectedModule.value)
)

function accessLabel(access?: string) {
  if (access === "allowed") return t('admin.operational_roles.show.permission_status_allowed')
  if (access === "restricted") return t('admin.operational_roles.show.permission_status_restricted')
  return t('admin.operational_roles.show.permission_status_denied')
}

function accessBadgeClass(access?: string) {
  if (access === "allowed") return "bg-green-100 text-green-800 border-green-200"
  if (access === "restricted") return "bg-yellow-100 text-yellow-800 border-yellow-200"
  return "bg-red-100 text-red-800 border-red-200"
}

const breadcrumbs = [
  { label: t('admin.sidebar.home'), href: "/admin/home/index" },
  { label: t('admin.operational_roles.index.title'), href: admin_operational_roles_path() },
  { label: props.role.name }
]
</script>
