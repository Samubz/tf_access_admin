<template>
  <div>
    <Header :itemsBreadcrumb="itemsBreadcrumb" :title="t('admin.property_sections.index.title')" />
    <AdminDataTable :columns="columns" :data="property_sections">
      <template #actions-table>
        <div class="w-full flex items-center justify-between gap-2">
          <div class="w-full md:w-1/2 flex gap-2">
            <Input
              type="search"
              :placeholder="t('admin.property_sections.index.input.search.placeholder')"
              v-model="search"
              @search="onSearchClear"
            />
            <Button variant="outline" @click="triggerSearch">
              <SearchIcon class="w-4 h-4" />
              {{ t('common.actions.search') }}
            </Button>
          </div>
          <Link :href="admin_residential_properties_path()">
            <Button variant="outline">
              {{ t('admin.property_sections.index.actions.manage_from_property') }}
            </Button>
          </Link>
        </div>
      </template>
      <template #actions="{ row }">
        <ListItem
          v-if="row.residential_property_id"
          as="link"
          :href="admin_property_setup_wizard_path(row.residential_property_id as string)"
        >
          <span class="flex items-center gap-2">
            <PencilIcon class="w-4 h-4" />
            {{ t('admin.property_sections.index.actions.manage_structure') }}
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
import { h, watch, onMounted, computed } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import AdminDataTable from '@/components/admin/table/index.vue'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import { useTable } from '@/lib/composables/useTable'
import { useI18n } from 'vue-i18n'
import type { ColumnDef } from '@/types/table'
import { Button } from '@/components/ui/button'
import { SearchIcon, PencilIcon } from 'lucide-vue-next'
import { Input } from '@/components/ui/input'
import {
  admin_residential_properties_path,
  admin_property_setup_wizard_path,
} from '@/routes'
import ListItem from '@/components/custom/list/ListItem.vue'
import Header from '@/components/admin/layout/Header.vue'
import type { PropertySection } from '@/types/property_section'
import { toast } from 'vue-sonner'
import { getPropertySectionsBreadcrumbs } from '@/lib/breadcrumbs/property_section'

const { t } = useI18n()

const props = defineProps<{
  property_sections: PropertySection[]
  pagination?: {
    current_page: number
    per_page: number
    total_pages: number
    total_count: number
  }
  errors?: Record<string, string[]>
}>()

const fetchData = (search: string, page: number, itemsPerPage: number) => {
  router.get(
    '/admin/property_sections',
    { page, per_page: itemsPerPage, q: { name_or_code_cont: search } },
    { preserveState: true }
  )
}

const itemsBreadcrumb = computed(() => getPropertySectionsBreadcrumbs(t))
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
  { immediate: false }
)

onMounted(() => {
  if (props.errors) {
    const firstError = props.errors[0]
    if (firstError) {
      toast.error(firstError)
    }
  }
})

const columns: ColumnDef<PropertySection, unknown>[] = [
  { accessorKey: 'name', header: () => t('admin.property_sections.index.table.headers.name') },
  { accessorKey: 'code', header: () => t('admin.property_sections.index.table.headers.code') },
  {
    accessorKey: 'section_type',
    header: () => t('admin.property_sections.index.table.headers.section_type'),
    cell: ({ row }) =>
      h('span', t(`admin.property_sections.section_types.${row.original.section_type}`)),
  },
  {
    accessorKey: 'residential_property_name',
    header: () => t('admin.property_sections.index.table.headers.residential_property'),
  },
  {
    accessorKey: 'parent_name',
    header: () => t('admin.property_sections.index.table.headers.parent'),
    cell: ({ row }) => h('span', row.original.parent_name ?? '—'),
  },
  {
    accessorKey: 'position',
    header: () => t('admin.property_sections.index.table.headers.position'),
    cell: ({ row }) => h('span', row.original.position ?? '—'),
  },
]

const onSearchClear = (e: Event) => {
  const target = e.target as HTMLInputElement
  if (target?.value === '') {
    triggerSearch()
  }
}
</script>
