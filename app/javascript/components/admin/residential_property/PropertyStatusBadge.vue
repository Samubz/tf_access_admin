<template>
  <StatusDotBadge :label="label" :tone="tone" />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import StatusDotBadge from '@/components/admin/shared/StatusDotBadge.vue'

const props = defineProps<{
  status: string
}>()

const { t } = useI18n()

const label = computed(() =>
  t(`admin.residential_properties.statuses.${props.status}`, props.status),
)

const tone = computed(() => {
  switch (props.status) {
    case 'active':
      return 'success' as const
    case 'inactive':
      return 'warning' as const
    case 'archived':
      return 'muted' as const
    default:
      return 'muted' as const
  }
})
</script>
