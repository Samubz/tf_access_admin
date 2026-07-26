<template>
  <AdminDataTable
    :columns="columns"
    :data="staffAssignments"
    :title="t('admin.people.profile.staff.title')"
    :description="t('admin.people.profile.staff.description')"
    :empty-message="t('admin.people.profile.staff.empty')"
  />
</template>

<script setup lang="ts">
import { computed, h } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminDataTable from '@/components/admin/table/index.vue'
import type { ColumnDef } from '@/types/table'
import type { PersonStaffAssignment } from '@/types/person_profile'

defineProps<{
  staffAssignments: PersonStaffAssignment[]
}>()

const { t } = useI18n()

const columns = computed<ColumnDef<PersonStaffAssignment, unknown>[]>(() => [
  {
    accessorKey: 'residential_property_name',
    header: () => t('admin.people.profile.staff.table.property'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'role',
    header: () => t('admin.people.profile.staff.table.role'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'status',
    header: () => t('admin.people.profile.staff.table.status'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'starts_at',
    header: () => t('admin.people.profile.staff.table.starts_at'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'ends_at',
    header: () => t('admin.people.profile.staff.table.ends_at'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
])
</script>
