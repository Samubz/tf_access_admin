<template>
  <AdminDataTable
    :columns="columns"
    :data="occupancies"
    :title="t('admin.people.profile.occupancies.title')"
    :description="t('admin.people.profile.occupancies.description')"
    :empty-message="t('admin.people.profile.occupancies.empty')"
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
import {
  admin_person_path,
  admin_property_setup_wizard_path,
  admin_residential_property_unit_path,
} from '@/routes'
import type { ColumnDef } from '@/types/table'
import type { PersonOccupancyRow } from '@/types/person_profile'

const props = defineProps<{
  personId: string
  occupancies: PersonOccupancyRow[]
  occupanciesPagination?: {
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
      tab: 'residences',
      occupancies_page: page,
      occupancies_per_page: itemsPerPage,
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
  initialPagination: props.occupanciesPagination,
})

const paginationMeta = computed(() => props.occupanciesPagination)

watch(
  () => props.occupanciesPagination,
  (meta) => {
    if (meta) setPagination(meta)
  },
  { immediate: false },
)

const columns = computed<ColumnDef<PersonOccupancyRow, unknown>[]>(() => [
  {
    accessorKey: 'residential_property_name',
    header: () => t('admin.people.profile.occupancies.table.property'),
    cell: ({ row }) => {
      const occupancy = row.original
      if (!occupancy.residential_property_name) return h('span', '—')

      return h(
        Link,
        {
          href: admin_property_setup_wizard_path(occupancy.residential_property_id),
          class: 'font-medium text-primary hover:underline',
        },
        () => occupancy.residential_property_name,
      )
    },
  },
  {
    accessorKey: 'property_section_name',
    header: () => t('admin.people.profile.occupancies.table.section'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'unit_identifier',
    header: () => t('admin.people.profile.occupancies.table.unit'),
    cell: ({ row }) => {
      const occupancy = row.original

      return h(
        Link,
        {
          href: admin_residential_property_unit_path(
            occupancy.residential_property_id,
            occupancy.unit_id,
          ),
          class: 'font-medium text-primary hover:underline',
        },
        () => occupancy.unit_identifier,
      )
    },
  },
  {
    accessorKey: 'occupancy_type_label',
    header: () => t('admin.people.profile.occupancies.table.type'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    id: 'validity',
    header: () => t('admin.people.profile.occupancies.table.validity'),
    cell: ({ row }) => {
      const occupancy = row.original
      const range = formatValidityRange(
        occupancy.starts_at,
        occupancy.ends_at,
        locale.value,
        t('admin.units.show.occupants.open_ended'),
      )

      return h('div', { class: 'space-y-0.5' }, [
        h('p', { class: 'text-sm' }, range),
        h(
          'p',
          {
            class: `text-xs font-medium ${validityStateClass(occupancy.validity_state)}`,
          },
          t(`admin.units.show.occupants.validity_states.${occupancy.validity_state}`),
        ),
      ])
    },
  },
  {
    accessorKey: 'status',
    header: () => t('admin.people.profile.occupancies.table.status'),
    cell: ({ row }) => {
      const occupancy = row.original

      return h(StatusDotBadge, {
        label: occupancy.status_label || t(`admin.units.show.occupants.statuses.${occupancy.status}`),
        tone: occupancy.status === 'active' ? 'success' : 'muted',
      })
    },
  },
])
</script>
