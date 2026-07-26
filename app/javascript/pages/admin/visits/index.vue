<template>
  <div>
    <Header :items-breadcrumb="itemsBreadcrumb" :title="t('admin.visits.index.title')" />

    <div class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
      <p class="text-muted-foreground max-w-3xl text-sm">
        {{ t('admin.visits.index.description') }}
      </p>
      <Link v-if="canCreate" :href="new_admin_visit_path()">
        <Button>
          <Plus class="size-4" />
          {{ t('admin.visits.index.actions.create') }}
        </Button>
      </Link>
    </div>

    <div v-if="showScopeSelector" class="mb-4 flex flex-wrap gap-2">
      <Button
        :variant="activeScope === 'organization' ? 'default' : 'outline'"
        size="sm"
        @click="changeScope('organization')"
      >
        {{ t('admin.visits.index.scope.organization') }}
      </Button>
      <Button
        :variant="activeScope === 'assigned' ? 'default' : 'outline'"
        size="sm"
        @click="changeScope('assigned')"
      >
        {{ t('admin.visits.index.scope.assigned') }}
      </Button>
    </div>

    <AdminDataTable :columns="columns" :data="visits">
      <template #actions-table>
        <div class="space-y-4">
          <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
            <div class="space-y-2">
              <Label for="property-filter">{{ t('admin.visits.index.filters.property') }}</Label>
              <NativeSelect id="property-filter" v-model="propertyFilter" class="w-full">
                <NativeSelectOption value="">
                  {{ t('admin.visits.index.filters.all_properties') }}
                </NativeSelectOption>
                <NativeSelectOption v-for="property in properties" :key="property.id" :value="property.id">
                  {{ property.name }}
                </NativeSelectOption>
              </NativeSelect>
            </div>
            <div class="space-y-2">
              <Label for="unit-filter">{{ t('admin.visits.index.filters.unit') }}</Label>
              <NativeSelect id="unit-filter" v-model="unitFilter" class="w-full">
                <NativeSelectOption value="">
                  {{ t('admin.visits.index.filters.all_units') }}
                </NativeSelectOption>
                <NativeSelectOption v-for="unit in filteredUnits" :key="unit.id" :value="unit.id">
                  {{ unit.display_name ?? unit.identifier }}
                </NativeSelectOption>
              </NativeSelect>
            </div>
            <div class="space-y-2">
              <Label for="status-filter">{{ t('admin.visits.index.filters.status') }}</Label>
              <NativeSelect id="status-filter" v-model="statusFilter" class="w-full">
                <NativeSelectOption value="">
                  {{ t('admin.visits.index.filters.all_statuses') }}
                </NativeSelectOption>
                <NativeSelectOption v-for="status in statuses" :key="status" :value="status">
                  {{ t(`admin.visits.statuses.${status}`) }}
                </NativeSelectOption>
              </NativeSelect>
            </div>
            <div class="space-y-2">
              <Label>{{ t('admin.visits.index.filters.date_range') }}</Label>
              <div class="flex gap-2">
                <Input v-model="dateFromFilter" type="date" />
                <Input v-model="dateToFilter" type="date" />
              </div>
            </div>
          </div>

          <div class="flex w-full flex-col gap-2 md:flex-row md:items-center md:justify-between">
            <div class="flex w-full flex-col gap-2 md:w-2/3 md:flex-row">
              <Input
                type="search"
                v-model="search"
                :placeholder="t('admin.visits.index.search.placeholder')"
                @search="onSearchClear"
              />
              <Button variant="outline" @click="triggerSearch">
                <Search class="size-4" />
                {{ t('common.actions.search') }}
              </Button>
            </div>
            <div class="flex gap-2">
              <Button variant="ghost" @click="clearFilters">
                {{ t('admin.visits.index.filters.clear') }}
              </Button>
              <Button @click="applyFilters">
                {{ t('admin.visits.index.filters.apply') }}
              </Button>
            </div>
          </div>
        </div>
      </template>

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

    <VisitCheckInDrawer
      v-model:open="checkInOpen"
      :visit="selectedVisit"
      namespace="admin"
      return-to="list"
      @success="refreshList"
    />
    <VisitCheckOutDrawer
      v-model:open="checkOutOpen"
      :visit="selectedVisit"
      namespace="admin"
      return-to="list"
      @success="refreshList"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, h, onMounted, ref, watch } from 'vue'
import { Link } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { Plus, Search } from 'lucide-vue-next'
import Header from '@/components/admin/layout/Header.vue'
import AdminDataTable from '@/components/admin/table/index.vue'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import VisitActionsDropdown from '@/components/admin/visits/VisitActionsDropdown.vue'
import VisitStatusBadge from '@/components/concierge/visits/VisitStatusBadge.vue'
import VisitCheckInDrawer from '@/components/concierge/visits/VisitCheckInDrawer.vue'
import VisitCheckOutDrawer from '@/components/concierge/visits/VisitCheckOutDrawer.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { NativeSelect, NativeSelectOption } from '@/components/ui/native-select'
import { useAdminVisitsList } from '@/lib/composables/admin/useAdminVisitsList'
import { useTable } from '@/lib/composables/useTable'
import { visitInitials } from '@/lib/utils/visit'
import { new_admin_visit_path } from '@/routes'
import type { ColumnDef } from '@/types/table'
import type {
  AdminVisitListItem,
  AdminVisitShowItem,
  AdminVisitScope,
  PropertySummary,
  UnitFilterOption,
} from '@/types/visit'
import type { BreadcrumbItem } from '@/types/layout'

const props = defineProps<{
  visits: AdminVisitListItem[]
  pagination?: {
    current_page: number
    per_page: number
    total_pages: number
    total_count: number
  }
  filters?: Record<string, string>
  scope?: AdminVisitScope
  show_scope_selector?: boolean
  can_create?: boolean
  properties?: PropertySummary[]
  units?: UnitFilterOption[]
  statuses?: string[]
}>()

const { t, locale } = useI18n()

const selectedVisit = ref<AdminVisitListItem | null>(null)
const checkInOpen = ref(false)
const checkOutOpen = ref(false)

const initialScope = (props.scope ?? 'organization') as AdminVisitScope
const {
  activeScope,
  propertyFilter,
  unitFilter,
  statusFilter,
  dateFromFilter,
  dateToFilter,
  fetchVisits,
  refreshList,
} = useAdminVisitsList(initialScope)

const showScopeSelector = computed(() => props.show_scope_selector ?? false)
const canCreate = computed(() => props.can_create ?? false)
const properties = computed(() => props.properties ?? [])
const statuses = computed(() => props.statuses ?? [])

if (props.filters?.residential_property_id_eq) propertyFilter.value = props.filters.residential_property_id_eq
if (props.filters?.unit_id_eq) unitFilter.value = props.filters.unit_id_eq
if (props.filters?.status_eq) statusFilter.value = props.filters.status_eq
if (props.filters?.scheduled_at_gteq) dateFromFilter.value = props.filters.scheduled_at_gteq.slice(0, 10)
if (props.filters?.scheduled_at_lteq) dateToFilter.value = props.filters.scheduled_at_lteq.slice(0, 10)

const filteredUnits = computed(() => {
  const allUnits = props.units ?? []
  if (!propertyFilter.value) return allUnits
  return allUnits.filter((unit) => unit.residential_property_id === propertyFilter.value)
})

const itemsBreadcrumb = computed<BreadcrumbItem[]>(() => [
  { label: t('admin.sidebar.home'), href: '/admin/home/index' },
  { label: t('admin.visits.index.title') },
])

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

function buildQuery(page: number, itemsPerPage: number) {
  fetchVisits({
    search: search.value,
    page,
    itemsPerPage,
    scope: activeScope.value,
    propertyId: propertyFilter.value,
    unitId: unitFilter.value,
    status: statusFilter.value,
    dateFrom: dateFromFilter.value,
    dateTo: dateToFilter.value,
  })
}

const fetchData = (searchValue: string, page: number, itemsPerPage: number) => {
  fetchVisits({
    search: searchValue,
    page,
    itemsPerPage,
    scope: activeScope.value,
    propertyId: propertyFilter.value,
    unitId: unitFilter.value,
    status: statusFilter.value,
    dateFrom: dateFromFilter.value,
    dateTo: dateToFilter.value,
  })
}

const {
  currentPage,
  totalPages,
  totalItems,
  itemsPerPage,
  itemsPerPageOptions,
  search,
  handlePageChange,
  handleItemsPerPageChange,
  setPagination,
  triggerSearch,
} = useTable(fetchData, {
  skipInitialFetch: true,
  initialPagination: props.pagination,
})

const paginationMeta = computed(() => props.pagination)

watch(
  () => props.pagination,
  (meta) => {
    if (meta) setPagination(meta)
  },
  { immediate: false },
)

watch(
  () => props.scope,
  (scope) => {
    if (scope) activeScope.value = scope
  },
)

watch(propertyFilter, () => {
  unitFilter.value = ''
})

onMounted(() => {
  const searchKey = 'visitor_person_display_name_or_unit_identifier_cont'
  if (props.filters?.[searchKey]) {
    search.value = props.filters[searchKey]
  }
})

function changeScope(scope: AdminVisitScope) {
  activeScope.value = scope
  buildQuery(1, itemsPerPage.value)
}

function applyFilters() {
  buildQuery(1, itemsPerPage.value)
}

function clearFilters() {
  propertyFilter.value = ''
  unitFilter.value = ''
  statusFilter.value = ''
  dateFromFilter.value = ''
  dateToFilter.value = ''
  search.value = ''
  buildQuery(1, itemsPerPage.value)
}

function onSearchClear(event: Event) {
  const target = event.target as HTMLInputElement
  if (target?.value === '') triggerSearch()
}

function onCheckIn(visit: AdminVisitListItem | AdminVisitShowItem) {
  selectedVisit.value = visit as AdminVisitListItem
  checkInOpen.value = true
}

function onCheckOut(visit: AdminVisitListItem | AdminVisitShowItem) {
  selectedVisit.value = visit as AdminVisitListItem
  checkOutOpen.value = true
}

const columns = computed<ColumnDef<AdminVisitListItem, unknown>[]>(() => [
  {
    id: 'visitor',
    header: () => t('admin.visits.index.table.headers.visitor'),
    cell: ({ row }) => {
      const visitor = row.original.visitor
      const name = visitor?.display_name ?? '—'
      return h('div', { class: 'flex items-center gap-3' }, [
        h(
          'div',
          {
            class:
              'bg-primary/10 text-primary flex size-9 shrink-0 items-center justify-center rounded-full text-xs font-semibold',
          },
          visitInitials(name),
        ),
        h('span', { class: 'font-medium' }, name),
      ])
    },
  },
  {
    id: 'unit',
    header: () => t('admin.visits.index.table.headers.unit'),
    cell: ({ row }) => h('span', row.original.unit?.display_name ?? row.original.unit?.identifier ?? '—'),
  },
  {
    id: 'property',
    header: () => t('admin.visits.index.table.headers.property'),
    cell: ({ row }) => h('span', row.original.residential_property?.name ?? '—'),
  },
  {
    id: 'authorizers',
    header: () => t('admin.visits.index.table.headers.authorizers'),
    cell: ({ row }) =>
      h('span', row.original.authorizers?.map((authorizer) => authorizer.display_name).join(', ') || '—'),
  },
  {
    id: 'status',
    header: () => t('admin.visits.index.table.headers.status'),
    cell: ({ row }) =>
      h(VisitStatusBadge, {
        status: row.original.status,
        label: row.original.status_label,
      }),
  },
  {
    id: 'scheduled_at',
    header: () => t('admin.visits.index.table.headers.date'),
    cell: ({ row }) => h('span', formatDate(row.original.scheduled_at)),
  },
  {
    id: 'checked_in_at',
    header: () => t('admin.visits.index.table.headers.check_in'),
    cell: ({ row }) => h('span', formatTime(row.original.checked_in_at)),
  },
  {
    id: 'checked_out_at',
    header: () => t('admin.visits.index.table.headers.check_out'),
    cell: ({ row }) => h('span', formatTime(row.original.checked_out_at)),
  },
  {
    id: 'actions',
    header: () => t('common.table.actions'),
    cell: ({ row }) =>
      h(VisitActionsDropdown, {
        visit: row.original,
        onCheckIn: onCheckIn,
        onCheckOut: onCheckOut,
        onSuccess: refreshList,
      }),
  },
])
</script>
