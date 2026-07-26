<template>
  <div class="space-y-6">
    <Breadcrumb :items="itemsBreadcrumb" />
    <Card class="w-full">
      <CardContent class="pt-6">
        <PersonProfileHeader
          :person="person"
          :contextual-roles="contextualRoles"
          :permissions="permissions"
        />
      </CardContent>
    </Card>

    <PersonProfileSummaryCards :summary="summary" />

    <TabNav
      v-model="activeTab"
      :tabs="tabs"
      :aria-label="t('admin.people.profile.tabs.aria_label')"
    />

    <div class="w-full">
      <PersonSummaryTab
        v-if="activeTab === 'summary'"
        :person="person"
        :contextual-roles="contextualRoles"
      />
      <PersonOwnershipsTab
        v-else-if="activeTab === 'properties'"
        :person-id="person.id as string"
        :ownerships="ownerships"
        :ownerships-pagination="ownershipsPagination"
      />
      <PersonOccupanciesTab
        v-else-if="activeTab === 'residences'"
        :person-id="person.id as string"
        :occupancies="occupancies"
        :occupancies-pagination="occupanciesPagination"
      />
      <PersonStaffTab
        v-else-if="activeTab === 'staff'"
        :staff-assignments="staffAssignments"
      />
      <PersonVisitsTab
        v-else-if="activeTab === 'visits'"
        :visits="visits"
      />
      <PersonHistoryTab
        v-else-if="activeTab === 'history'"
        :change-history="changeHistory"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import {
  Building2,
  ClipboardList,
  History,
  Home,
  LayoutGrid,
  Users,
} from 'lucide-vue-next'
import Breadcrumb from '@/components/admin/layout/Breadcrumb.vue'
import PersonHistoryTab from '@/components/admin/person/profile/PersonHistoryTab.vue'
import PersonOccupanciesTab from '@/components/admin/person/profile/PersonOccupanciesTab.vue'
import PersonOwnershipsTab from '@/components/admin/person/profile/PersonOwnershipsTab.vue'
import PersonProfileHeader from '@/components/admin/person/profile/PersonProfileHeader.vue'
import PersonProfileSummaryCards from '@/components/admin/person/profile/PersonProfileSummaryCards.vue'
import PersonStaffTab from '@/components/admin/person/profile/PersonStaffTab.vue'
import PersonSummaryTab from '@/components/admin/person/profile/PersonSummaryTab.vue'
import PersonVisitsTab from '@/components/admin/person/profile/PersonVisitsTab.vue'
import TabNav, { type TabNavItem } from '@/components/admin/shared/TabNav.vue'
import { getPersonShowBreadcrumbs } from '@/lib/breadcrumbs/person'
import { admin_person_path } from '@/routes'
import type { Person } from '@/types/person'
import type {
  PersonChangeHistoryEntry,
  PersonContextualRole,
  PersonOccupancyRow,
  PersonOwnershipRow,
  PersonProfilePermissions,
  PersonProfileSummary,
  PersonStaffAssignment,
  PersonVisitRow,
} from '@/types/person_profile'
import type { TableMeta } from '@/types/table'
import { Card, CardContent } from '@/components/ui/card'

const PROFILE_TABS = [
  'summary',
  'properties',
  'residences',
  'staff',
  'visits',
  'history',
] as const

type ProfileTab = (typeof PROFILE_TABS)[number]

const props = defineProps<{
  person: Person
  contextual_roles: PersonContextualRole[]
  summary: PersonProfileSummary
  ownerships: PersonOwnershipRow[]
  ownerships_pagination: TableMeta
  occupancies: PersonOccupancyRow[]
  occupancies_pagination: TableMeta
  change_history: PersonChangeHistoryEntry[]
  staff_assignments: PersonStaffAssignment[]
  visits: PersonVisitRow[]
  permissions: PersonProfilePermissions
}>()

const { t } = useI18n()
const page = usePage()

function resolveInitialTab(): ProfileTab {
  const url = new URL(page.url, window.location.origin)
  const tab = url.searchParams.get('tab')

  if (tab && PROFILE_TABS.includes(tab as ProfileTab)) {
    return tab as ProfileTab
  }

  return 'summary'
}

const activeTab = ref<ProfileTab>(resolveInitialTab())

const itemsBreadcrumb = computed(() =>
  getPersonShowBreadcrumbs(t, props.person.display_name),
)

const contextualRoles = computed(() => props.contextual_roles)
const summary = computed(() => props.summary)
const ownerships = computed(() => props.ownerships)
const ownershipsPagination = computed(() => props.ownerships_pagination)
const occupancies = computed(() => props.occupancies)
const occupanciesPagination = computed(() => props.occupancies_pagination)
const changeHistory = computed(() => props.change_history)
const staffAssignments = computed(() => props.staff_assignments)
const visits = computed(() => props.visits)
const permissions = computed(() => props.permissions)
const person = computed(() => props.person)

const tabs = computed<TabNavItem[]>(() => [
  { id: 'summary', label: t('admin.people.profile.tabs.summary'), icon: LayoutGrid },
  { id: 'properties', label: t('admin.people.profile.tabs.properties'), icon: Building2 },
  { id: 'residences', label: t('admin.people.profile.tabs.residences'), icon: Home },
  { id: 'staff', label: t('admin.people.profile.tabs.staff'), icon: Users },
  { id: 'visits', label: t('admin.people.profile.tabs.visits'), icon: ClipboardList },
  { id: 'history', label: t('admin.people.profile.tabs.history'), icon: History },
])

watch(activeTab, (tab) => {
  const url = new URL(page.url, window.location.origin)
  if (url.searchParams.get('tab') === tab) return

  router.get(
    admin_person_path(props.person.id as string),
    {
      tab,
      ownerships_page: props.ownerships_pagination.current_page,
      occupancies_page: props.occupancies_pagination.current_page,
    },
    { preserveState: true, replace: true, preserveScroll: true },
  )
})
</script>
