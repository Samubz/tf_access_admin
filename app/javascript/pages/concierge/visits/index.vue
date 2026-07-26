<template>
  <div>
    <Header :items-breadcrumb="itemsBreadcrumb" :title="t('concierge.visits.index.title')" />

    <div class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
      <p class="text-muted-foreground max-w-2xl text-sm">
        {{ t('concierge.visits.index.description') }}
      </p>
      <Card v-if="assignedProperty" class="w-full shrink-0 border-dashed lg:w-auto">
        <CardContent class="flex items-center gap-3 p-4">
          <Building2 class="text-muted-foreground size-5" />
          <div>
            <p class="text-muted-foreground text-xs">
              {{ t('concierge.visits.index.assigned_property') }}
            </p>
            <p class="font-medium">{{ assignedProperty.name }}</p>
          </div>
        </CardContent>
      </Card>
    </div>

    <div class="mb-4 flex flex-wrap gap-2">
      <Button
        v-for="tab in tabs"
        :key="tab.key"
        :variant="activeTab === tab.key ? 'default' : 'outline'"
        size="sm"
        class="gap-2"
        @click="changeTab(tab.key)"
      >
        {{ tab.label }}
        <Badge variant="secondary" class="tabular-nums">{{ tab.count }}</Badge>
      </Button>
    </div>

    <AdminDataTable :columns="columns" :data="visits" :empty-message="emptyStateMessage">
      <template #actions-table>
        <div class="flex w-full flex-col gap-3 md:flex-row md:items-center">
          <div class="flex w-full flex-col gap-2 md:flex-row">
            <Input
              type="search"
              v-model="search"
              :placeholder="t('concierge.visits.index.search.placeholder')"
              @search="onSearchClear"
            />
            <Button variant="outline" @click="triggerSearch">
              <Search class="size-4" />
              {{ t('common.actions.search') }}
            </Button>
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
      return-to="list"
      @success="refreshList"
    />
    <VisitCheckOutDrawer
      v-model:open="checkOutOpen"
      :visit="selectedVisit"
      return-to="list"
      @success="refreshList"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, h, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, Search } from 'lucide-vue-next'
import Header from '@/components/admin/layout/Header.vue'
import AdminDataTable from '@/components/admin/table/index.vue'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import VisitDenialNotice from '@/components/concierge/visits/VisitDenialNotice.vue'
import VisitRowActions from '@/components/concierge/visits/VisitRowActions.vue'
import VisitStatusBadge from '@/components/concierge/visits/VisitStatusBadge.vue'
import VisitCheckInDrawer from '@/components/concierge/visits/VisitCheckInDrawer.vue'
import VisitCheckOutDrawer from '@/components/concierge/visits/VisitCheckOutDrawer.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { useTable } from '@/lib/composables/useTable'
import { useConciergeVisitsList } from '@/lib/composables/concierge/useConciergeVisitsList'
import {
  formatVisitDuration,
  visitAuthorizedTime,
  visitInitials,
} from '@/lib/utils/visit'
import type { ColumnDef } from '@/types/table'
import type {
  AssignedPropertySummary,
  ConciergeVisitCounters,
  ConciergeVisitListItem,
  ConciergeVisitTab,
} from '@/types/visit'
import type { BreadcrumbItem } from '@/types/layout'

const props = defineProps<{
  visits: ConciergeVisitListItem[]
  pagination?: {
    current_page: number
    per_page: number
    total_pages: number
    total_count: number
  }
  tab?: ConciergeVisitTab
  query?: string | null
  counters: ConciergeVisitCounters
  assigned_property?: AssignedPropertySummary | null
}>()

const { t, locale } = useI18n()
const selectedVisit = ref<ConciergeVisitListItem | null>(null)
const checkInOpen = ref(false)
const checkOutOpen = ref(false)

const initialTab = (props.tab ?? 'expected_today') as ConciergeVisitTab
const { activeTab, fetchVisits, refreshList } = useConciergeVisitsList(initialTab)

const itemsBreadcrumb = computed<BreadcrumbItem[]>(() => [
  { label: t('admin.sidebar.home'), href: '/admin/home/index' },
  { label: t('concierge.visits.index.title') },
])

const tabs = computed(() => [
  {
    key: 'expected_today' as const,
    label: t('concierge.visits.index.tabs.expected_today'),
    count: props.counters.expected_today,
  },
  {
    key: 'currently_inside' as const,
    label: t('concierge.visits.index.tabs.currently_inside'),
    count: props.counters.currently_inside,
  },
])

const assignedProperty = computed(() => props.assigned_property ?? null)
const isSearching = computed(() => Boolean(props.query?.trim()))

const emptyStateMessage = computed(() => {
  if (isSearching.value) {
    return t('concierge.visits.index.empty.search')
  }

  return activeTab.value === 'currently_inside'
    ? t('concierge.visits.index.empty.currently_inside')
    : t('concierge.visits.index.empty.expected_today')
})

function formatDateTime(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}

function currentDuration(visit: ConciergeVisitListItem) {
  if (visit.duration_seconds != null && visit.duration_seconds >= 0) {
    return formatVisitDuration(visit.duration_seconds)
  }

  if (!visit.checked_in_at) return '—'

  const checkedInAt = new Date(visit.checked_in_at).getTime()
  if (Number.isNaN(checkedInAt)) return '—'

  const seconds = Math.max(0, Math.floor((Date.now() - checkedInAt) / 1000))
  return formatVisitDuration(seconds)
}

function loadList(page: number, itemsPerPage: number) {
  fetchVisits({
    search: search.value,
    page,
    itemsPerPage,
    tab: activeTab.value,
    propertyId: assignedProperty.value?.id,
  })
}

const fetchData = (searchValue: string, page: number, itemsPerPage: number) => {
  fetchVisits({
    search: searchValue,
    page,
    itemsPerPage,
    tab: activeTab.value,
    propertyId: assignedProperty.value?.id,
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
  () => props.tab,
  (tab) => {
    if (tab) activeTab.value = tab
  },
)

onMounted(() => {
  if (props.query) {
    search.value = props.query
  }
})

function changeTab(tab: ConciergeVisitTab) {
  activeTab.value = tab
  loadList(1, itemsPerPage.value)
}

function onSearchClear(event: Event) {
  const target = event.target as HTMLInputElement
  if (target?.value === '') triggerSearch()
}

function onCheckIn(visit: ConciergeVisitListItem) {
  selectedVisit.value = visit
  checkInOpen.value = true
}

function onCheckOut(visit: ConciergeVisitListItem) {
  selectedVisit.value = visit
  checkOutOpen.value = true
}

const columns = computed<ColumnDef<ConciergeVisitListItem, unknown>[]>(() => {
  const timeHeader =
    activeTab.value === 'currently_inside'
      ? t('concierge.visits.index.table.headers.checked_in_at')
      : t('concierge.visits.index.table.headers.scheduled_at')

  const baseColumns: ColumnDef<ConciergeVisitListItem, unknown>[] = [
    {
      id: 'visitor',
      header: () => t('concierge.visits.index.table.headers.visitor'),
      cell: ({ row }) => {
        const visit = row.original

        if (visit.denial_explanation) {
          return h(VisitDenialNotice, { visit })
        }

        const visitor = visit.visitor
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
      header: () => t('concierge.visits.index.table.headers.unit'),
      cell: ({ row }) => {
        if (row.original.denial_explanation) return h('span', '—')
        const unit = row.original.unit
        return h('span', unit?.display_name ?? unit?.identifier ?? '—')
      },
    },
    {
      id: 'authorizers',
      header: () => t('concierge.visits.index.table.headers.authorizers'),
      cell: ({ row }) => {
        if (row.original.denial_explanation) return h('span', '—')
        return h(
          'span',
          row.original.authorizers?.map((authorizer) => authorizer.display_name).join(', ') || '—',
        )
      },
    },
    {
      id: 'status',
      header: () => t('concierge.visits.index.table.headers.status'),
      cell: ({ row }) =>
        h(VisitStatusBadge, {
          visit: row.original,
          status: row.original.status,
          label: row.original.status_label,
        }),
    },
    {
      id: 'time',
      header: () => timeHeader,
      cell: ({ row }) => {
        const visit = row.original
        if (visit.denial_explanation) return h('span', '—')

        if (activeTab.value === 'currently_inside') {
          return h('span', formatDateTime(visit.checked_in_at))
        }

        return h('span', formatDateTime(visit.scheduled_at ?? visitAuthorizedTime(visit)))
      },
    },
  ]

  if (activeTab.value === 'currently_inside') {
    baseColumns.push({
      id: 'duration',
      header: () => t('concierge.visits.index.table.headers.duration'),
      cell: ({ row }) => {
        if (row.original.denial_explanation) return h('span', '—')
        return h('span', { class: 'tabular-nums' }, currentDuration(row.original))
      },
    })
  }

  baseColumns.push({
    id: 'actions',
    header: () => t('common.table.actions'),
    cell: ({ row }) => {
      if (row.original.denial_explanation) return h('span', '—')

      return h(VisitRowActions, {
        visit: row.original,
        onCheckIn: onCheckIn,
        onCheckOut: onCheckOut,
      })
    },
  })

  return baseColumns
})
</script>
