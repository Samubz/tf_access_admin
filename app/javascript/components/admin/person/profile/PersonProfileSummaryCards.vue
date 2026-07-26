<template>
  <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
    <MetricCard
      v-for="card in cards"
      :key="card.key"
      :icon="card.icon"
      :label="card.label"
      :value="card.value"
      :icon-class="card.iconClass"
      :icon-wrapper-class="card.iconWrapperClass"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, ClipboardList, Home, Users } from 'lucide-vue-next'
import MetricCard from '@/components/admin/shared/MetricCard.vue'
import type { PersonProfileSummary } from '@/types/person_profile'

const props = defineProps<{
  summary: PersonProfileSummary
}>()

const { t } = useI18n()

const cards = computed(() => [
  {
    key: 'ownerships',
    icon: Building2,
    label: t('admin.people.profile.metrics.active_ownerships'),
    value: props.summary.active_ownerships_count,
    iconClass: 'text-green-600',
    iconWrapperClass: 'bg-green-500/10',
  },
  {
    key: 'occupancies',
    icon: Home,
    label: t('admin.people.profile.metrics.active_occupancies'),
    value: props.summary.active_occupancies_count,
    iconClass: 'text-blue-600',
    iconWrapperClass: 'bg-blue-500/10',
  },
  {
    key: 'visits',
    icon: ClipboardList,
    label: t('admin.people.profile.metrics.visits'),
    value: props.summary.visits_count,
    iconClass: 'text-amber-600',
    iconWrapperClass: 'bg-amber-500/10',
  },
  {
    key: 'staff',
    icon: Users,
    label: t('admin.people.profile.metrics.staff'),
    value: props.summary.staff_assignments_count,
    iconClass: 'text-violet-600',
    iconWrapperClass: 'bg-violet-500/10',
  },
])
</script>
