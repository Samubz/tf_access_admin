<template>
  <div>
    <Header :itemsBreadcrumb="itemsBreadcrumb" :title="t('admin.residential_properties.index.title')" />
    <AdminDataTable :columns="columns" :data="residential_properties">
      <template #actions-table>
        <div class="w-full flex items-center justify-between gap-2">
          <div class="w-full md:w-1/2 flex gap-2">
            <Input
              type="search"
              :placeholder="t('admin.residential_properties.index.input.search.placeholder')"
              v-model="search"
              @search="onSearchClear"
            />
            <Button variant="outline" @click="triggerSearch">
              <SearchIcon class="w-4 h-4" />
              {{ t('common.actions.search') }}
            </Button>
          </div>
          <Link v-if="canCreate" :href="admin_property_setup_new_wizard_path()">
            <Button>
              <PlusIcon class="w-4 h-4" />
              {{ t('admin.residential_properties.index.actions.create') }}
            </Button>
          </Link>
        </div>
      </template>
      <template #actions="{ row }">
        <ListItem as="link" :href="admin_residential_property_path(row.id as string)">
          <span class="flex items-center gap-2">
            <Eye class="w-4 h-4" />
            {{ t('admin.residential_properties.index.actions.view_detail') }}
          </span>
        </ListItem>
        <ListItem
          v-if="row.permissions?.update && wizardEditableStatuses.includes(row.status)"
          as="link"
          :href="admin_property_setup_wizard_path(row.id as string)"
        >
          <span class="flex items-center gap-2">
            <Layers class="w-4 h-4" />
            {{ t('admin.residential_properties.index.actions.setup_wizard') }}
          </span>
        </ListItem>
        <ListItem
          v-if="row.permissions?.archive"
          as="confirm"
          :onClick="() => archiveProperty(row.id as string)"
          :confirmTitle="t('admin.residential_properties.index.actions.archive')"
          :confirmDescription="
            t('admin.residential_properties.index.actions.archive_description', { name: row.name })
          "
        >
          <span class="flex items-center gap-2">
            <Loader2 v-if="archivingId === row.id" class="w-4 h-4 animate-spin" />
            <ArchiveIcon v-else class="w-4 h-4" />
            {{ t('admin.residential_properties.index.actions.archive') }}
          </span>
        </ListItem>
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
  </div>
</template>

<script setup lang="ts">
import { computed, h, onMounted, ref, watch } from 'vue'
import { Link, router, usePage } from '@inertiajs/vue3'
import AdminDataTable from '@/components/admin/table/index.vue'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import PropertyStatusBadge from '@/components/admin/residential_property/PropertyStatusBadge.vue'
import { useTable } from '@/lib/composables/useTable'
import { useI18n } from 'vue-i18n'
import type { ColumnDef } from '@/types/table'
import { Button } from '@/components/ui/button'
import { PlusIcon, SearchIcon, ArchiveIcon, Layers, Loader2, Eye } from 'lucide-vue-next'
import { Input } from '@/components/ui/input'
import {
  admin_property_setup_new_wizard_path,
  admin_property_setup_wizard_path,
  admin_residential_property_path,
} from '@/routes'
import ListItem from '@/components/custom/list/ListItem.vue'
import Header from '@/components/admin/layout/Header.vue'
import type { ResidentialProperty } from '@/types/residential_property'
import { toast } from 'vue-sonner'
import { getResidentialPropertiesBreadcrumbs } from '@/lib/breadcrumbs/residential_property'

const { t } = useI18n()
const page = usePage()

const props = defineProps<{
  residential_properties: ResidentialProperty[]
  pagination?: {
    current_page: number
    per_page: number
    total_pages: number
    total_count: number
  }
  errors?: Record<string, string[]>
}>()

const archivingId = ref<string | null>(null)
const canCreate = computed(() => Boolean((page.props.capabilities as Record<string, boolean>)?.manage_properties))
// Statuses the setup wizard can reopen for editing (enable-wizard-editing-created-state).
const wizardEditableStatuses = ['draft', 'created', 'configured', 'active']

const fetchData = (search: string, pageNumber: number, itemsPerPage: number) => {
  router.get(
    '/admin/residential_properties',
    { page: pageNumber, per_page: itemsPerPage, q: { name_or_code_or_city_cont: search } },
    { preserveState: true },
  )
}

const itemsBreadcrumb = computed(() => getResidentialPropertiesBreadcrumbs(t))
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
const paginationMeta = props.pagination

watch(
  () => props.pagination,
  (meta) => {
    if (meta) setPagination(meta)
  },
  { immediate: false },
)

onMounted(() => {
  const baseErrors = props.errors?.base
  if (baseErrors?.length) {
    toast.error(baseErrors[0])
    return
  }

  const firstError = props.errors ? Object.values(props.errors).flat()[0] : undefined
  if (firstError) toast.error(firstError)
})

const columns: ColumnDef<ResidentialProperty, unknown>[] = [
  { accessorKey: 'name', header: () => t('admin.residential_properties.index.table.headers.name') },
  { accessorKey: 'code', header: () => t('admin.residential_properties.index.table.headers.code') },
  {
    accessorKey: 'property_type',
    header: () => t('admin.residential_properties.index.table.headers.property_type'),
    cell: ({ row }) =>
      h('span', t(`admin.residential_properties.property_types.${row.original.property_type}`)),
  },
  { accessorKey: 'city', header: () => t('admin.residential_properties.index.table.headers.city') },
  {
    id: 'status',
    header: () => t('admin.residential_properties.index.table.headers.status'),
    cell: ({ row }) => h(PropertyStatusBadge, { status: row.original.status }),
  },
]

function archiveProperty(id: string) {
  archivingId.value = id
  router.post(
    `/admin/residential_properties/${id}/archive`,
    {},
    {
      onSuccess: () => {
        toast.success(t('admin.residential_properties.index.actions.archive_success'))
      },
      onError: () => {
        toast.error(t('admin.residential_properties.index.actions.archive_error'))
      },
      onFinish: () => {
        archivingId.value = null
      },
    },
  )
}

function onSearchClear(e: Event) {
  const target = e.target as HTMLInputElement
  if (target?.value === '') {
    triggerSearch()
  }
}
</script>
