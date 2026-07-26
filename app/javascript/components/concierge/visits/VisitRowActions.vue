<template>
  <div class="flex flex-wrap items-center justify-end gap-2">
    <Button
      v-if="canCheckIn"
      size="sm"
      class="gap-1.5"
      @click="emit('checkIn', visit)"
    >
      <LogIn class="size-4" />
      {{ t('concierge.visits.actions.check_in') }}
    </Button>
    <Button
      v-else-if="canCheckOut"
      size="sm"
      variant="secondary"
      class="gap-1.5"
      @click="emit('checkOut', visit)"
    >
      <LogOut class="size-4" />
      {{ t('concierge.visits.actions.check_out') }}
    </Button>

    <p
      v-else-if="showExpiredInstruction"
      class="text-muted-foreground max-w-[12rem] text-right text-xs leading-snug"
    >
      {{ t('concierge.visits.instructions.request_new_authorization') }}
    </p>

    <VisitActionsDropdown
      v-if="canShow && !canCheckIn && !canCheckOut"
      :visit="visit"
      @check-in="emit('checkIn', visit)"
      @check-out="emit('checkOut', visit)"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { LogIn, LogOut } from 'lucide-vue-next'
import VisitActionsDropdown from '@/components/concierge/visits/VisitActionsDropdown.vue'
import { visitEffectiveStatus } from '@/lib/utils/visit'
import { Button } from '@/components/ui/button'
import type { ConciergeVisitListItem } from '@/types/visit'

const props = defineProps<{
  visit: ConciergeVisitListItem
}>()

const emit = defineEmits<{
  checkIn: [visit: ConciergeVisitListItem]
  checkOut: [visit: ConciergeVisitListItem]
}>()

const { t } = useI18n()

const canShow = computed(() => props.visit.permissions.show)
const canCheckIn = computed(() => props.visit.permissions.check_in)
const canCheckOut = computed(() => props.visit.permissions.check_out)
const showExpiredInstruction = computed(
  () => visitEffectiveStatus(props.visit) === 'expired' && !canCheckIn.value && !canCheckOut.value,
)
</script>
