<template>
  <AdminDataTable
    :columns="columns"
    :data="ownerships"
    :title="t('admin.people.profile.ownerships.title')"
    :description="t('admin.people.profile.ownerships.description')"
    :empty-message="t('admin.people.profile.ownerships.empty')"
  >
    <template v-if="paginationMeta" #footer>
      <DataTablePagination
        :current-page="currentPage"
        :total-pages="totalPages"
        :total-items="totalItems"
        :items-per-page="itemsPerPage"
        :items-per-page-options="itemsPerPageOptions"
        :on-page-change="handlePageChange"
        :on-items-per-page-change="handleItemsPerPageChange"
      />
    </template>
  </AdminDataTable>
</template>

<script setup lang="ts">
import { computed, h, watch } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import AdminDataTable from '@/components/admin/table/index.vue'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import StatusDotBadge from '@/components/admin/shared/StatusDotBadge.vue'
import { useTable } from '@/lib/composables/useTable'
import {
  formatValidityRange,
  validityStateClass,
} from '@/lib/utils/validity'
import { formatOwnershipPercentage } from '@/lib/utils/unit'
import {
  admin_person_path,
  admin_property_setup_wizard_path,
  admin_residential_property_unit_path,
} from '@/routes'
import type { ColumnDef } from '@/types/table'
import type { PersonOwnershipRow } from '@/types/person_profile'

const props = defineProps<{
  personId: string
  ownerships: PersonOwnershipRow[]
  ownershipsPagination?: {
    current_page: number
    per_page: number
    total_pages: number
    total_count: number
  }
}>()

const { t, locale } = useI18n()

const fetchData = (_search: string, page: number, itemsPerPage: number) => {
  router.get(
    admin_person_path(props.personId),
    {
      tab: 'properties',
      ownerships_page: page,
      ownerships_per_page: itemsPerPage,
    },
    { preserveState: true, preserveScroll: true },
  )
}

const {
  currentPage,
  totalPages,
  totalItems,
  itemsPerPage,
  itemsPerPageOptions,
  handlePageChange,
  handleItemsPerPageChange,
  setPagination,
} = useTable(fetchData, {
  skipInitialFetch: true,
  initialPagination: props.ownershipsPagination,
})

const paginationMeta = computed(() => props.ownershipsPagination)

watch(
  () => props.ownershipsPagination,
  (meta) => {
    if (meta) setPagination(meta)
  },
  { immediate: false },
)

const columns = computed<ColumnDef<PersonOwnershipRow, unknown>[]>(() => [
  {
    accessorKey: 'residential_property_name',
    header: () => t('admin.people.profile.ownerships.table.property'),
    cell: ({ row }) => {
      const ownership = row.original
      if (!ownership.residential_property_name) return h('span', '—')

      return h(
        Link,
        {
          href: admin_property_setup_wizard_path(ownership.residential_property_id),
          class: 'font-medium text-primary hover:underline',
        },
        () => ownership.residential_property_name,
      )
    },
  },
  {
    accessorKey: 'property_section_name',
    header: () => t('admin.people.profile.ownerships.table.section'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'unit_identifier',
    header: () => t('admin.people.profile.ownerships.table.unit'),
    cell: ({ row }) => {
      const ownership = row.original

      return h(
        Link,
        {
          href: admin_residential_property_unit_path(
            ownership.residential_property_id,
            ownership.unit_id,
          ),
          class: 'font-medium text-primary hover:underline',
        },
        () => ownership.unit_identifier,
      )
    },
  },
  {
    accessorKey: 'ownership_percentage',
    header: () => t('admin.people.profile.ownerships.table.percentage'),
    cell: ({ getValue }) => h('span', formatOwnershipPercentage(getValue() as number)),
  },
  {
    id: 'validity',
    header: () => t('admin.people.profile.ownerships.table.validity'),
    cell: ({ row }) => {
      const ownership = row.original
      const range = formatValidityRange(
        ownership.starts_at,
        ownership.ends_at,
        locale.value,
        t('admin.units.show.owners.open_ended'),
      )

      return h('div', { class: 'space-y-0.5' }, [
        h('p', { class: 'text-sm' }, range),
        h(
          'p',
          {
            class: `text-xs font-medium ${validityStateClass(ownership.validity_state)}`,
          },
          t(`admin.units.show.owners.validity_states.${ownership.validity_state}`),
        ),
      ])
    },
  },
  {
    accessorKey: 'status',
    header: () => t('admin.people.profile.ownerships.table.status'),
    cell: ({ row }) => {
      const ownership = row.original

      return h(StatusDotBadge, {
        label: t(`admin.units.show.owners.statuses.${ownership.status}`),
        tone: ownership.status === 'active' ? 'success' : 'muted',
      })
    },
  },
])
</script>
