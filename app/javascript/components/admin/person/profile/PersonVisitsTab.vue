<template>
  <AdminDataTable
    :columns="columns"
    :data="visits"
    :title="t('admin.people.profile.visits.title')"
    :description="t('admin.people.profile.visits.description')"
    :empty-message="t('admin.people.profile.visits.empty')"
  />
</template>

<script setup lang="ts">
import { computed, h } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminDataTable from '@/components/admin/table/index.vue'
import type { ColumnDef } from '@/types/table'
import type { PersonVisitRow } from '@/types/person_profile'

defineProps<{
  visits: PersonVisitRow[]
}>()

const { t, locale } = useI18n()

function formatDateTime(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}

const columns = computed<ColumnDef<PersonVisitRow, unknown>[]>(() => [
  {
    accessorKey: 'occurred_at',
    header: () => t('admin.people.profile.visits.table.occurred_at'),
    cell: ({ getValue }) => h('span', formatDateTime(getValue() as string)),
  },
  {
    accessorKey: 'residential_property_name',
    header: () => t('admin.people.profile.visits.table.property'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'unit_identifier',
    header: () => t('admin.people.profile.visits.table.unit'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'status',
    header: () => t('admin.people.profile.visits.table.status'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
])
</script>
