<template>
  <div>
    <Header :itemsBreadcrumb="breadcrumbs" :title="t('admin.operational_roles.assignments.title')" />
    <p class="px-6 -mt-2 mb-2 text-sm text-muted-foreground">{{ t('admin.operational_roles.assignments.subtitle') }}</p>

    <div class="p-6 space-y-4">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <div class="flex items-center gap-2 flex-1 flex-wrap">
          <Input
            type="search"
            :placeholder="t('admin.operational_roles.assignments.filters.search_person')"
            v-model="searchQuery"
            class="max-w-xs"
            @keyup.enter="applyFilters"
          />
          <select
            v-model="roleFilter"
            class="h-9 rounded-md border border-input bg-background px-3 text-sm"
            @change="applyFilters"
          >
            <option value="">{{ t('admin.operational_roles.assignments.filters.all_roles') }}</option>
            <option v-for="r in available_roles" :key="r.key" :value="r.key">{{ r.name }}</option>
          </select>
          <select
            v-model="propertyFilter"
            class="h-9 rounded-md border border-input bg-background px-3 text-sm"
            @change="applyFilters"
          >
            <option value="">{{ t('admin.operational_roles.assignments.filters.all_properties') }}</option>
            <option v-for="p in accessible_properties" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </div>
        <Button v-if="permissions.create" @click="drawerOpen = true">
          <PlusIcon class="w-4 h-4 mr-1" />
          {{ t('admin.operational_roles.assignments.new_assignment_button') }}
        </Button>
      </div>

      <AdminDataTable
        :columns="columns"
        :data="assignments"
        :empty-message="t('admin.operational_roles.assignments.empty_message')"
      >
        <template #actions="{ row }">
          <ListItem
            v-if="permissions.destroy"
            as="confirm"
            :onClick="() => confirmRevoke(row)"
            :confirmTitle="t('admin.operational_roles.assignments.revoke_confirmation_title')"
            :confirmDescription="t('admin.operational_roles.assignments.revoke_confirmation_description', {
              role: row.role,
              person: row.person_name
            })"
          >
            <span class="flex items-center gap-2 text-destructive">
              <XCircleIcon class="w-4 h-4" />
              {{ t('admin.operational_roles.assignments.revoke_action') }}
            </span>
          </ListItem>
        </template>
        <template v-if="pagination" #footer>
          <DataTablePagination
            :current-page="currentPage"
            :total-pages="totalPages"
            :total-items="totalItems"
            :items-per-page="itemsPerPage"
            :items-per-page-options="[10, 25, 50]"
            :on-page-change="handlePageChange"
            :on-items-per-page-change="handleItemsPerPageChange"
          />
        </template>
      </AdminDataTable>
    </div>

    <AssignRoleDrawer
      :open="drawerOpen"
      :available_roles="available_roles"
      :accessible_properties="accessible_properties"
      :assignable_people="assignable_people"
      @close="drawerOpen = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, h } from "vue"
import { router } from "@inertiajs/vue3"
import { useI18n } from "vue-i18n"
import Header from "@/components/admin/layout/Header.vue"
import AdminDataTable from "@/components/admin/table/index.vue"
import DataTablePagination from "@/components/admin/table/DataTablePagination.vue"
import ListItem from "@/components/custom/list/ListItem.vue"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { PlusIcon, XCircleIcon } from "lucide-vue-next"
import AssignRoleDrawer from "@/components/admin/operational_roles/AssignRoleDrawer.vue"
import RoleBadge from "@/components/admin/operational_roles/RoleBadge.vue"
import {
  admin_operational_roles_assignments_path,
  admin_operational_roles_assignment_path,
  admin_operational_roles_path
} from "@/routes"
import type {
  AssignmentRow,
  AccessibleProperty,
  AssignablePerson,
  AvailableRoleOption
} from "@/types/operational_roles"
import type { ColumnDef } from "@/types/table"

const { t } = useI18n()

interface PaginationMeta {
  current_page: number
  total_pages: number
  total_count: number
  per_page: number
}

const props = defineProps<{
  assignments: AssignmentRow[]
  pagination: PaginationMeta | null
  available_roles: AvailableRoleOption[]
  accessible_properties: AccessibleProperty[]
  assignable_people: AssignablePerson[]
  permissions: { create: boolean; destroy: boolean }
}>()

const breadcrumbs = [
  { label: t('admin.sidebar.home'), href: "/admin/home/index" },
  { label: t('admin.operational_roles.index.title'), href: admin_operational_roles_path() },
  { label: t('admin.operational_roles.assignments.title') }
]

const drawerOpen = ref(false)
const searchQuery = ref("")
const roleFilter = ref("")
const propertyFilter = ref<string>("")

const currentPage = computed(() => props.pagination?.current_page ?? 1)
const totalPages = computed(() => props.pagination?.total_pages ?? 1)
const totalItems = computed(() => props.pagination?.total_count ?? 0)
const itemsPerPage = computed(() => props.pagination?.per_page ?? 10)

const columns = computed<ColumnDef<AssignmentRow>[]>(() => [
  {
    accessorKey: "user_email",
    header: t('admin.operational_roles.assignments.table_headers.user'),
    cell: ({ row }) => {
      const assignment = row.original
      return h("div", { class: "space-y-0.5" }, [
        h("p", { class: "font-medium" }, assignment.user_name || assignment.user_email || "—"),
        assignment.user_email ? h("p", { class: "text-xs text-muted-foreground" }, assignment.user_email) : null
      ])
    }
  },
  {
    accessorKey: "person_name",
    header: t('admin.operational_roles.assignments.table_headers.person'),
    cell: ({ row }) => row.original.person_name ?? "—"
  },
  {
    accessorKey: "role",
    header: t('admin.operational_roles.assignments.table_headers.role'),
    cell: ({ row }) => h(RoleBadge, { roleKey: row.original.role_key, label: row.original.role ?? "—" })
  },
  {
    accessorKey: "scope_label",
    header: t('admin.operational_roles.assignments.table_headers.scope'),
    cell: ({ row }) => row.original.scope_label ?? "—"
  },
  {
    accessorKey: "status",
    header: t('admin.operational_roles.assignments.table_headers.status'),
    cell: ({ row }) => h(
      Badge,
      {
        class: row.original.status === "active" ? "bg-green-100 text-green-800 border-green-200" : "",
        variant: "outline"
      },
      () => row.original.status === "active" ? t('common.status.active') : t('common.status.inactive')
    )
  },
  {
    accessorKey: "starts_at",
    header: t('admin.operational_roles.assignments.table_headers.from'),
    cell: ({ row }) => row.original.starts_at ?? "—"
  },
  {
    accessorKey: "ends_at",
    header: t('admin.operational_roles.assignments.table_headers.to'),
    cell: ({ row }) => row.original.ends_at ?? "—"
  }
])

function applyFilters() {
  router.get(admin_operational_roles_assignments_path(), {
    q: searchQuery.value || undefined,
    role: roleFilter.value || undefined,
    property_id: propertyFilter.value || undefined
  }, { preserveState: true })
}

function handlePageChange(page: number) {
  router.get(admin_operational_roles_assignments_path(), { page }, { preserveState: true })
}

function handleItemsPerPageChange(perPage: number) {
  router.get(admin_operational_roles_assignments_path(), { per_page: perPage, page: 1 }, { preserveState: true })
}

function confirmRevoke(assignment: AssignmentRow) {
  router.delete(admin_operational_roles_assignment_path(assignment.id))
}
</script>
