<template>
  <div class="space-y-4">
    <div class="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{{ t('admin.units.show.owners.table.owner') }}</TableHead>
            <TableHead>{{ t('admin.units.show.owners.table.document') }}</TableHead>
            <TableHead>{{ t('admin.units.show.owners.table.email') }}</TableHead>
            <TableHead>{{ t('admin.units.show.owners.table.percentage') }}</TableHead>
            <TableHead>{{ t('admin.units.show.owners.table.validity') }}</TableHead>
            <TableHead>{{ t('admin.units.show.owners.table.status') }}</TableHead>
            <TableHead class="w-[4rem] text-right">{{ t('common.table.actions') }}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-if="ownerships.length === 0">
            <TableCell colspan="7" class="h-24 text-center text-muted-foreground">
              {{ t('admin.units.show.owners.table.empty') }}
            </TableCell>
          </TableRow>
          <TableRow v-for="ownership in ownerships" :key="ownership.id">
            <TableCell>
              <PersonProfileLink :person-id="ownership.person_id">
                <Avatar class="size-9">
                  <AvatarFallback>{{ personInitials(ownership.person_display_name) }}</AvatarFallback>
                </Avatar>
                <span>{{ ownership.person_display_name }}</span>
              </PersonProfileLink>
            </TableCell>
            <TableCell class="text-muted-foreground">
              {{ documentLabel(ownership) }}
            </TableCell>
            <TableCell class="text-muted-foreground">
              {{ ownership.person_email || '—' }}
            </TableCell>
            <TableCell>
              <OwnershipProgress
                :percentage="ownership.ownership_percentage"
                :active="ownership.status === 'active'"
              />
            </TableCell>
            <TableCell>
              <div class="space-y-0.5">
                <p class="text-sm">{{ validityRange(ownership) }}</p>
                <p
                  class="text-xs font-medium"
                  :class="validityStateClass(ownership.validity_state)"
                >
                  {{ t(`admin.units.show.owners.validity_states.${ownership.validity_state}`) }}
                </p>
              </div>
            </TableCell>
            <TableCell>
              <StatusDotBadge
                :label="t(`admin.units.show.owners.statuses.${ownership.status}`)"
                :tone="ownership.status === 'active' ? 'success' : 'muted'"
              />
            </TableCell>
            <TableCell class="text-right">
              <DropdownMenu>
                <DropdownMenuTrigger as-child>
                  <Button
                    variant="ghost"
                    size="icon"
                    :aria-label="t('common.table.actions')"
                  >
                    <MoreHorizontal class="size-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem @click="emit('edit', ownership)">
                    <Pencil class="size-4" />
                    {{ t('common.actions.edit') }}
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    class="text-destructive focus:text-destructive"
                    @click="emit('delete', ownership)"
                  >
                    <Trash2 class="size-4" />
                    {{ t('common.actions.delete') }}
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
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
import { router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { MoreHorizontal, Pencil, Trash2 } from 'lucide-vue-next'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import PersonProfileLink from '@/components/admin/person/PersonProfileLink.vue'
import OwnershipProgress from '@/components/admin/shared/OwnershipProgress.vue'
import StatusDotBadge from '@/components/admin/shared/StatusDotBadge.vue'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { useTable } from '@/lib/composables/useTable'
import { personInitials } from '@/lib/utils/unit'
import { admin_residential_property_unit_path } from '@/routes'
import type { UnitOwnership, UnitOwnershipsPagination } from '@/types/unit'

const props = defineProps<{
  ownerships: UnitOwnership[]
  residentialPropertyId: string
  unitId: string
  ownershipsPagination?: UnitOwnershipsPagination
}>()

const emit = defineEmits<{
  (e: 'edit', ownership: UnitOwnership): void
  (e: 'delete', ownership: UnitOwnership): void
}>()

const { t, locale } = useI18n()

const fetchData = (_search: string, page: number, itemsPerPage: number) => {
  router.get(
    admin_residential_property_unit_path(props.residentialPropertyId, props.unitId),
    { page, per_page: itemsPerPage },
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

function documentLabel(ownership: UnitOwnership) {
  if (!ownership.person_document_number) return '—'

  const type = ownership.person_document_type
    ? `${ownership.person_document_type} `
    : ''

  return `${type}${ownership.person_document_number}`.trim()
}

function validityRange(ownership: UnitOwnership) {
  const start = formatDate(ownership.starts_at)
  const end = ownership.ends_at ? formatDate(ownership.ends_at) : t('admin.units.show.owners.open_ended')

  return `${start} – ${end}`
}

function formatDate(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium' }).format(date)
}

function validityStateClass(state: UnitOwnership['validity_state']) {
  if (state === 'current') return 'text-green-600'
  if (state === 'finished') return 'text-destructive'
  return 'text-muted-foreground'
}
</script>
