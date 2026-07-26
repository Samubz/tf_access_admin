<template>
  <div class="space-y-6 w-full">
    <PanelHeader
      :title="t('admin.units.show.visits.title')"
      :description="t('admin.units.show.visits.description')"
    >
      <template #actions>
        <Link v-if="permissions.create" :href="createVisitHref">
          <Button>
            <Plus class="size-4" />
            {{ t('admin.units.show.visits.actions.create') }}
          </Button>
        </Link>
      </template>
    </PanelHeader>

    <UnitVisitsTable
      :visits="visits"
      :unit="unit"
      :visits-pagination="visitsPagination"
      @success="refreshVisits"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { Plus } from 'lucide-vue-next'
import PanelHeader from '@/components/admin/shared/PanelHeader.vue'
import UnitVisitsTable from '@/components/admin/unit/UnitVisitsTable.vue'
import { Button } from '@/components/ui/button'
import { new_admin_visit_path } from '@/routes'
import type { UnitDetail } from '@/types/unit'
import type { AdminVisitListItem, UnitVisitPermissions, UnitVisitsPagination } from '@/types/visit'

const props = withDefaults(
  defineProps<{
    unit: UnitDetail
    visits: AdminVisitListItem[]
    visitsPagination?: UnitVisitsPagination
    permissions?: UnitVisitPermissions
  }>(),
  {
    visits: () => [],
    permissions: () => ({ create: false }),
  },
)

const { t } = useI18n()

const createVisitHref = computed(() =>
  new_admin_visit_path({ unit_id: props.unit.id, return_to: 'unit' }),
)

function refreshVisits() {
  router.reload({ only: ['visits', 'visits_pagination'] })
}
</script>
