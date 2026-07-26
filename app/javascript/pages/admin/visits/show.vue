<template>
  <div>
    <Header :items-breadcrumb="itemsBreadcrumb" :title="pageTitle" />

    <div class="mb-6 space-y-6">
      <VisitDetailHeader
        :visit="visit"
        @check-in="openCheckIn"
        @check-out="openCheckOut"
        @success="reloadVisit"
      />

      <template v-if="isFullDetail">
        <TabNav
          v-model="activeTab"
          :tabs="tabs"
          :aria-label="t('admin.visits.show.tabs.aria_label')"
        />

        <VisitDetailInfoTab
          v-if="activeTab === 'info'"
          :visit="visit as AdminVisitDetail"
          :locale="locale"
        />
        <VisitDetailDocumentsTab v-else-if="activeTab === 'documents'" />
        <VisitDetailHistoryTab
          v-else-if="activeTab === 'history'"
          :history="visit.history"
          :locale="locale"
        />
      </template>

      <VisitDetailContextualPanel
        v-else-if="isContextualDetailView"
        :visit="visit as AdminVisitContextualDetail"
        :locale="locale"
      />

      <VisitDetailRestrictedPanel
        v-else
        :visit="visit as AdminVisitRestrictedDetail"
        :locale="locale"
      />
    </div>

    <VisitCheckInDrawer
      v-model:open="checkInOpen"
      :visit="operationalVisit"
      namespace="admin"
      return-to="detail"
      @success="reloadVisit"
    />
    <VisitCheckOutDrawer
      v-model:open="checkOutOpen"
      :visit="operationalVisit"
      namespace="admin"
      return-to="detail"
      @success="reloadVisit"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { FileText, History, Info } from 'lucide-vue-next'
import Header from '@/components/admin/layout/Header.vue'
import TabNav, { type TabNavItem } from '@/components/admin/shared/TabNav.vue'
import VisitDetailContextualPanel from '@/components/admin/visits/detail/VisitDetailContextualPanel.vue'
import VisitDetailDocumentsTab from '@/components/admin/visits/detail/VisitDetailDocumentsTab.vue'
import VisitDetailHeader from '@/components/admin/visits/detail/VisitDetailHeader.vue'
import VisitDetailHistoryTab from '@/components/admin/visits/detail/VisitDetailHistoryTab.vue'
import VisitDetailInfoTab from '@/components/admin/visits/detail/VisitDetailInfoTab.vue'
import VisitDetailRestrictedPanel from '@/components/admin/visits/detail/VisitDetailRestrictedPanel.vue'
import VisitCheckInDrawer from '@/components/concierge/visits/VisitCheckInDrawer.vue'
import VisitCheckOutDrawer from '@/components/concierge/visits/VisitCheckOutDrawer.vue'
import { isContextualVisitDetail, isFullVisitDetail } from '@/lib/utils/visit_detail'
import { admin_residential_property_unit_path, admin_visits_path } from '@/routes'
import type {
  AdminVisitContextualDetail,
  AdminVisitDetail,
  AdminVisitListItem,
  AdminVisitRestrictedDetail,
  AdminVisitShowItem,
} from '@/types/visit'
import type { BreadcrumbItem } from '@/types/layout'

const props = defineProps<{
  visit: AdminVisitShowItem
}>()

const { t, locale } = useI18n()
const activeTab = ref('info')
const checkInOpen = ref(false)
const checkOutOpen = ref(false)
const selectedVisit = ref<AdminVisitListItem | null>(null)

const isFullDetail = computed(() => isFullVisitDetail(props.visit))
const isContextualDetailView = computed(() => isContextualVisitDetail(props.visit))

const pageTitle = computed(
  () => props.visit.visitor?.display_name ?? t('admin.visits.show.title'),
)

const itemsBreadcrumb = computed<BreadcrumbItem[]>(() => {
  if (isContextualVisitDetail(props.visit)) {
    const visit = props.visit
    const propertyId = visit.residential_property?.id ?? ''
    const unitId = visit.unit?.id ?? ''
    const unitLabel = visit.unit?.display_name ?? visit.unit?.identifier ?? ''

    return [
      {
        label: unitLabel,
        href: admin_residential_property_unit_path(propertyId, unitId, { tab: 'visits' }),
      },
      { label: pageTitle.value },
    ]
  }

  return [
    { label: t('admin.sidebar.manage_visits'), href: admin_visits_path() },
    { label: pageTitle.value },
  ]
})

const tabs = computed<TabNavItem[]>(() => [
  { id: 'info', label: t('admin.visits.show.tabs.info'), icon: Info },
  { id: 'documents', label: t('admin.visits.show.tabs.documents'), icon: FileText },
  { id: 'history', label: t('admin.visits.show.tabs.history'), icon: History },
])

const operationalVisit = computed(() => selectedVisit.value ?? (props.visit as AdminVisitListItem))

function openCheckIn(visit: AdminVisitShowItem) {
  selectedVisit.value = visit as AdminVisitListItem
  checkInOpen.value = true
}

function openCheckOut(visit: AdminVisitShowItem) {
  selectedVisit.value = visit as AdminVisitListItem
  checkOutOpen.value = true
}

function reloadVisit() {
  router.reload({ only: ['visit'] })
}
</script>
