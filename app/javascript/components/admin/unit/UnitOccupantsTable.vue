<template>
  <div class="space-y-4">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div class="flex items-center gap-2">
        <Checkbox
          id="occupants-include-inactive"
          :model-value="includeInactive"
          @update:model-value="(value) => emit('update:includeInactive', value === true)"
        />
        <Label for="occupants-include-inactive" class="text-sm font-normal cursor-pointer">
          {{ t('admin.units.show.occupants.filters.include_inactive') }}
        </Label>
      </div>
    </div>

    <div class="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{{ t('admin.units.show.occupants.table.occupant') }}</TableHead>
            <TableHead>{{ t('admin.units.show.occupants.table.document') }}</TableHead>
            <TableHead>{{ t('admin.units.show.occupants.table.occupancy_type') }}</TableHead>
            <TableHead>{{ t('admin.units.show.occupants.table.can_authorize_visits') }}</TableHead>
            <TableHead>{{ t('admin.units.show.occupants.table.validity') }}</TableHead>
            <TableHead>{{ t('admin.units.show.occupants.table.status') }}</TableHead>
            <TableHead v-if="showActionsColumn" class="w-[4rem] text-right">
              {{ t('common.table.actions') }}
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-if="occupancies.length === 0">
            <TableCell
              :colspan="showActionsColumn ? 7 : 6"
              class="h-24 text-center text-muted-foreground"
            >
              {{ emptyMessage }}
            </TableCell>
          </TableRow>
          <TableRow v-for="occupancy in occupancies" :key="occupancy.id">
            <TableCell>
              <div class="flex items-center gap-3">
                <Avatar class="size-9">
                  <AvatarFallback>{{ personInitials(occupancy.person_display_name) }}</AvatarFallback>
                </Avatar>
                <div class="min-w-0">
                  <PersonProfileLink :person-id="occupancy.person_id">
                    <span class="truncate">{{ occupancy.person_display_name }}</span>
                  </PersonProfileLink>
                  <p v-if="occupancy.person_email" class="text-xs text-muted-foreground truncate">
                    {{ occupancy.person_email }}
                  </p>
                </div>
              </div>
            </TableCell>
            <TableCell class="text-muted-foreground">
              {{ documentLabel(occupancy) }}
            </TableCell>
            <TableCell>
              <Badge variant="secondary">{{ occupancy.occupancy_type_label }}</Badge>
            </TableCell>
            <TableCell>
              <StatusDotBadge
                :label="authorizationLabel(occupancy.can_authorize_visits)"
                :tone="occupancy.can_authorize_visits ? 'success' : 'muted'"
              />
            </TableCell>
            <TableCell>
              <div class="space-y-0.5">
                <p class="text-sm">{{ validityRange(occupancy) }}</p>
                <p
                  class="text-xs font-medium"
                  :class="validityStateClass(occupancy.validity_state)"
                >
                  {{ t(`admin.units.show.occupants.validity_states.${occupancy.validity_state}`) }}
                </p>
              </div>
            </TableCell>
            <TableCell>
              <StatusDotBadge
                :label="occupancy.status_label"
                :tone="occupancy.status === 'active' ? 'success' : 'muted'"
              />
            </TableCell>
            <TableCell v-if="showActionsColumn" class="text-right">
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
                  <DropdownMenuItem
                    v-if="permissions.update"
                    @click="emit('edit', occupancy)"
                  >
                    <Pencil class="size-4" />
                    {{ t('common.actions.edit') }}
                  </DropdownMenuItem>
                  <DropdownMenuItem
                    v-if="permissions.update"
                    @click="emit('toggle-status', occupancy)"
                  >
                    <Power class="size-4" />
                    {{
                      occupancy.status === 'active'
                        ? t('admin.units.show.occupants.actions.deactivate')
                        : t('admin.units.show.occupants.actions.activate')
                    }}
                  </DropdownMenuItem>
                  <DropdownMenuSeparator v-if="permissions.update && permissions.destroy" />
                  <DropdownMenuItem
                    v-if="permissions.destroy"
                    class="text-destructive focus:text-destructive"
                    @click="emit('delete', occupancy)"
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
import { MoreHorizontal, Pencil, Power, Trash2 } from 'lucide-vue-next'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import PersonProfileLink from '@/components/admin/person/PersonProfileLink.vue'
import StatusDotBadge from '@/components/admin/shared/StatusDotBadge.vue'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Label } from '@/components/ui/label'
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
import type {
  UnitOccupanciesPagination,
  UnitOccupancy,
  UnitOccupancyPermissions,
} from '@/types/unit'

const props = defineProps<{
  occupancies: UnitOccupancy[]
  residentialPropertyId: string
  unitId: string
  occupanciesPagination?: UnitOccupanciesPagination
  includeInactive: boolean
  permissions: UnitOccupancyPermissions
}>()

const emit = defineEmits<{
  (e: 'edit', occupancy: UnitOccupancy): void
  (e: 'toggle-status', occupancy: UnitOccupancy): void
  (e: 'delete', occupancy: UnitOccupancy): void
  (e: 'update:includeInactive', value: boolean): void
}>()

const { t, locale } = useI18n()

const showActionsColumn = computed(
  () => props.permissions.update || props.permissions.destroy,
)

const emptyMessage = computed(() =>
  props.includeInactive
    ? t('admin.units.show.occupants.table.empty_all')
    : t('admin.units.show.occupants.table.empty'),
)

const fetchData = (_search: string, page: number, itemsPerPage: number) => {
  router.get(
    admin_residential_property_unit_path(props.residentialPropertyId, props.unitId),
    {
      tab: 'occupants',
      occupancies_page: page,
      occupancies_per_page: itemsPerPage,
      occupancies_include_inactive: props.includeInactive,
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

function documentLabel(occupancy: UnitOccupancy) {
  if (!occupancy.person_document_number) return '—'

  const type = occupancy.person_document_type ? `${occupancy.person_document_type} ` : ''
  return `${type}${occupancy.person_document_number}`.trim()
}

function authorizationLabel(canAuthorize: boolean) {
  return canAuthorize
    ? t('admin.units.show.occupants.authorization.yes')
    : t('admin.units.show.occupants.authorization.no')
}

function validityRange(occupancy: UnitOccupancy) {
  const start = formatDate(occupancy.starts_at)
  const end = occupancy.ends_at
    ? formatDate(occupancy.ends_at)
    : t('admin.units.show.occupants.open_ended')

  return `${start} – ${end}`
}

function formatDate(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium' }).format(date)
}

function validityStateClass(state: UnitOccupancy['validity_state']) {
  if (state === 'current') return 'text-green-600'
  if (state === 'finished') return 'text-destructive'
  return 'text-muted-foreground'
}
</script>
