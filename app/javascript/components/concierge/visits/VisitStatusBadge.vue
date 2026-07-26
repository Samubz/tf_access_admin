<template>
  <StatusDotBadge :label="displayLabel" :tone="tone" />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import StatusDotBadge from '@/components/admin/shared/StatusDotBadge.vue'
import { visitEffectiveStatus, visitEffectiveStatusLabel, visitStatusTone } from '@/lib/utils/visit'
import type { ConciergeVisitListItem } from '@/types/visit'

const props = defineProps<{
  status: string
  label: string
  effectiveStatus?: string
  effectiveLabel?: string
  visit?: ConciergeVisitListItem
}>()

const displayStatus = computed(() => {
  if (props.visit) return visitEffectiveStatus(props.visit)
  return props.effectiveStatus ?? props.status
})

const displayLabel = computed(() => {
  if (props.visit) return visitEffectiveStatusLabel(props.visit)
  return props.effectiveLabel ?? props.label
})

const tone = computed(() => visitStatusTone(displayStatus.value))
</script>
