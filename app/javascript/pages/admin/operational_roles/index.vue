<template>
  <div>
    <Header :itemsBreadcrumb="breadcrumbs" :title="t('admin.operational_roles.index.title')" />
    <p class="px-6 -mt-2 mb-2 text-sm text-muted-foreground">{{ t('admin.operational_roles.index.subtitle') }}</p>

    <div class="p-6 space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="rounded-lg border bg-card p-5">
          <p class="text-sm text-muted-foreground">{{ t('admin.operational_roles.index.summary_defined_roles') }}</p>
          <p class="text-3xl font-bold mt-1">{{ summary.defined_roles_count }}</p>
        </div>
        <div class="rounded-lg border bg-card p-5">
          <p class="text-sm text-muted-foreground">{{ t('admin.operational_roles.index.summary_total_capabilities') }}</p>
          <p class="text-3xl font-bold mt-1">{{ summary.total_capabilities_count }}</p>
        </div>
        <div class="rounded-lg border bg-card p-5">
          <p class="text-sm text-muted-foreground">{{ t('admin.operational_roles.index.summary_assigned_users') }}</p>
          <p class="text-3xl font-bold mt-1">{{ summary.assigned_users_count }}</p>
        </div>
        <div class="rounded-lg border bg-card p-5">
          <p class="text-sm text-muted-foreground">{{ t('admin.operational_roles.index.summary_active_assignments') }}</p>
          <p class="text-3xl font-bold mt-1">{{ summary.total_assignments_count }}</p>
        </div>
      </div>

      <div class="rounded-lg border bg-card">
        <div class="flex items-center justify-between px-6 py-4 border-b">
          <h2 class="font-semibold text-base">{{ t('admin.operational_roles.index.defined_roles_heading') }}</h2>
          <Link v-if="permissions.manage" :href="admin_operational_roles_assignments_path()">
            <Button size="sm">
              <PlusIcon class="w-4 h-4 mr-1" />
              {{ t('admin.operational_roles.index.assign_role_button') }}
            </Button>
          </Link>
        </div>
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b bg-muted/40">
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.index.table_headers.role') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.index.table_headers.description') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.index.table_headers.scope') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.index.table_headers.active_users') }}</th>
              <th class="text-left px-6 py-3 font-medium text-muted-foreground">{{ t('admin.operational_roles.index.table_headers.status') }}</th>
              <th class="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="role in roles" :key="role.key" class="border-b last:border-0 hover:bg-muted/20">
              <td class="px-6 py-4 font-medium">{{ role.name }}</td>
              <td class="px-6 py-4 text-muted-foreground max-w-sm">{{ role.description }}</td>
              <td class="px-6 py-4">
                <Badge variant="outline">{{ role.scope_label }}</Badge>
              </td>
              <td class="px-6 py-4">{{ role.users_count }}</td>
              <td class="px-6 py-4">
                <Badge class="bg-green-100 text-green-800 border-green-200">{{ t('admin.operational_roles.index.role_status_active') }}</Badge>
              </td>
              <td class="px-6 py-4 text-right">
                <DropdownMenu>
                  <DropdownMenuTrigger as-child>
                    <Button variant="ghost" size="icon">
                      <MoreHorizontalIcon class="w-4 h-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem as-child>
                      <Link :href="admin_operational_role_path(role.key)" class="flex items-center gap-2 cursor-pointer">
                        <EyeIcon class="w-4 h-4" />
                        {{ t('admin.operational_roles.index.view_detail') }}
                      </Link>
                    </DropdownMenuItem>
                    <DropdownMenuItem v-if="permissions.manage && role.assignable" as-child>
                      <Link :href="admin_operational_roles_assignments_path()" class="flex items-center gap-2 cursor-pointer">
                        <UserPlusIcon class="w-4 h-4" />
                        {{ t('admin.operational_roles.index.assign_persons') }}
                      </Link>
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <RolePermissionsMatrix :capability_matrix="capability_matrix" :role-columns="matrix_role_columns" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { Link } from "@inertiajs/vue3"
import { useI18n } from "vue-i18n"
import Header from "@/components/admin/layout/Header.vue"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import { PlusIcon, MoreHorizontalIcon, EyeIcon, UserPlusIcon } from "lucide-vue-next"
import RolePermissionsMatrix from "@/components/admin/operational_roles/RolePermissionsMatrix.vue"
import {
  admin_operational_role_path,
  admin_operational_roles_assignments_path,
  admin_operational_roles_path
} from "@/routes"
import type { OperationalRoleDefinition, CapabilityModuleGroup, RoleSummary, MatrixRoleColumn } from "@/types/operational_roles"

const { t } = useI18n()

defineProps<{
  roles: OperationalRoleDefinition[]
  summary: RoleSummary
  capability_matrix: CapabilityModuleGroup[]
  matrix_role_columns: MatrixRoleColumn[]
  permissions: { manage: boolean }
}>()

const breadcrumbs = [
  { label: t('admin.sidebar.home'), href: "/admin/home/index" },
  { label: t('admin.operational_roles.index.title'), href: admin_operational_roles_path() }
]
</script>
