<template>
  <div>
    <Header :items-breadcrumb="itemsBreadcrumb" :title="visit.visitor?.display_name ?? t('concierge.visits.show.title')" />

    <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <VisitStatusBadge :visit="visit" :status="visit.status" :label="visit.status_label" />
      <VisitRowActions
        :visit="visit"
        @check-in="openCheckIn"
        @check-out="openCheckOut"
      />
    </div>

    <VisitDetailPanel :visit="visit" />

    <div class="mt-6">
      <Link href="/concierge/visits">
        <Button variant="outline">{{ t('concierge.visits.show.back_to_list') }}</Button>
      </Link>
    </div>

    <VisitCheckInDrawer
      v-model:open="checkInOpen"
      :visit="visit"
      return-to="detail"
      @success="reloadVisit"
    />
    <VisitCheckOutDrawer
      v-model:open="checkOutOpen"
      :visit="visit"
      return-to="detail"
      @success="reloadVisit"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import Header from '@/components/admin/layout/Header.vue'
import VisitDetailPanel from '@/components/concierge/visits/VisitDetailPanel.vue'
import VisitRowActions from '@/components/concierge/visits/VisitRowActions.vue'
import VisitStatusBadge from '@/components/concierge/visits/VisitStatusBadge.vue'
import VisitCheckInDrawer from '@/components/concierge/visits/VisitCheckInDrawer.vue'
import VisitCheckOutDrawer from '@/components/concierge/visits/VisitCheckOutDrawer.vue'
import { Button } from '@/components/ui/button'
import type { ConciergeVisitSummary } from '@/types/visit'
import type { BreadcrumbItem } from '@/types/layout'

const props = defineProps<{
  visit: ConciergeVisitSummary
}>()

const { t } = useI18n()
const checkInOpen = ref(false)
const checkOutOpen = ref(false)

const itemsBreadcrumb = computed<BreadcrumbItem[]>(() => [
  { label: t('admin.sidebar.home'), href: '/admin/home/index' },
  { label: t('concierge.visits.index.title'), href: '/concierge/visits' },
  { label: props.visit.visitor?.display_name ?? t('concierge.visits.show.title') },
])

function openCheckIn() {
  checkInOpen.value = true
}

function openCheckOut() {
  checkOutOpen.value = true
}

function reloadVisit() {
  router.reload({ only: ['visit'] })
}
</script>
