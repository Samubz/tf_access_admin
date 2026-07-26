<template>
  <div
    class="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950"
    role="status"
  >
    <p class="font-medium">{{ visit.visitor?.display_name ?? '—' }}</p>
    <p class="mt-1">{{ visit.denial_explanation }}</p>
    <p
      v-if="showExpiredInstruction"
      class="text-muted-foreground mt-2 text-xs"
    >
      {{ t('concierge.visits.instructions.request_new_authorization') }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { visitEffectiveStatus } from '@/lib/utils/visit'
import type { ConciergeVisitListItem } from '@/types/visit'

const props = defineProps<{
  visit: ConciergeVisitListItem
}>()

const { t } = useI18n()

const showExpiredInstruction = computed(() => visitEffectiveStatus(props.visit) === 'expired')
</script>
