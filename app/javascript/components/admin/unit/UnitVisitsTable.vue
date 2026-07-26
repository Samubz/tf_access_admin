<template>
  <div class="space-y-4">
    <div class="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{{ t('admin.units.show.visits.table.visitor') }}</TableHead>
            <TableHead>{{ t('admin.units.show.visits.table.authorizers') }}</TableHead>
            <TableHead>{{ t('admin.units.show.visits.table.reason') }}</TableHead>
            <TableHead>{{ t('admin.units.show.visits.table.scheduled_at') }}</TableHead>
            <TableHead>{{ t('admin.units.show.visits.table.status') }}</TableHead>
            <TableHead class="w-[4rem] text-right">{{ t('common.table.actions') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-if="visits.length === 0">
            <TableCell colspan="6" class="h-24 text-center text-muted-foreground">
              {{ t('admin.units.show.visits.table.empty') }}
            </TableCell>
          </TableRow>
          <TableRow v-for="visit in visits" :key="visit.id">
            <TableCell>
              <Link :href="admin_visit_path(visit.id)" class="font-medium hover:underline">
                {{ visit.visitor?.display_name ?? '—' }}
              </Link>
            </TableCell>
            <TableCell class="text-muted-foreground">
              {{ visit.authorizers?.map((authorizer) => authorizer.display_name).join(', ') || '—' }}
            </TableCell>
            <TableCell class="text-muted-foreground">
              {{ visit.visit_type_label ?? '—' }}
            </TableCell>
            <TableCell class="text-muted-foreground">
              <div class="space-y-0.5">
                <p>{{ formatDate(visit.scheduled_at) }}</p>
                <p class="text-xs">{{ formatTime(visit.scheduled_at) }}</p>
              </div>
            </TableCell>
            <TableCell>
              <VisitStatusBadge :status="visit.status" :label="visit.status_label" />
            </TableCell>
            <TableCell class="text-right">
              <VisitActionsDropdown :visit="visit" @success="emit('success')" />
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <DataTablePagination
      v-if="paginationMeta && paginationMeta.total_count > 0"
      :current-page="currentPage"
      :total-pages="totalPages"
      :total-items="totalItems"
      :items-per-page="itemsPerPage"
      :items-per-page-options="itemsPerPageOptions"
      :on-page-change="handlePageChange"
      :on-items-per-page-change="handleItemsPerPageChange"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import VisitActionsDropdown from '@/components/admin/visits/VisitActionsDropdown.vue'
import VisitStatusBadge from '@/components/concierge/visits/VisitStatusBadge.vue'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { useTable } from '@/lib/composables/useTable'
import { admin_residential_property_unit_path, admin_visit_path } from '@/routes'
import type { UnitDetail } from '@/types/unit'
import type { AdminVisitListItem, UnitVisitsPagination } from '@/types/visit'

const props = defineProps<{
  visits: AdminVisitListItem[]
  unit: UnitDetail
  visitsPagination?: UnitVisitsPagination
}>()

const emit = defineEmits<{
  success: []
}>()

const { t, locale } = useI18n()

const unitShowPath = computed(() =>
  admin_residential_property_unit_path(props.unit.residential_property_id, props.unit.id, {
    tab: 'visits',
  }),
)

const fetchData = (_search: string, page: number, itemsPerPage: number) => {
  router.get(
    unitShowPath.value,
    { visits_page: page, visits_per_page: itemsPerPage, tab: 'visits' },
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
  initialPagination: props.visitsPagination,
})

const paginationMeta = computed(() => props.visitsPagination)

watch(
  () => props.visitsPagination,
  (meta) => {
    if (meta) setPagination(meta)
  },
  { immediate: false },
)

function formatDate(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium' }).format(date)
}

function formatTime(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat(locale.value, { timeStyle: 'short' }).format(date)
}
</script>
