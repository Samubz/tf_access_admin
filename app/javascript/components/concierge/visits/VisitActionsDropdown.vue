<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <Button variant="ghost" size="icon" class="h-8 w-8 p-0">
        <EllipsisVertical class="size-4" />
        <span class="sr-only">{{ t('concierge.visits.actions.open_menu') }}</span>
      </Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end" class="w-48">
      <DropdownMenuItem v-if="canShow" as-child>
        <Link :href="showHref" class="flex w-full cursor-pointer items-center gap-2">
          <Eye class="size-4" />
          {{ t('concierge.visits.actions.view') }}
        </Link>
      </DropdownMenuItem>
      <DropdownMenuItem
        v-if="canCheckIn"
        class="cursor-pointer"
        @select="emit('checkIn', visit)"
      >
        <LogIn class="size-4" />
        {{ t('concierge.visits.actions.check_in') }}
      </DropdownMenuItem>
      <DropdownMenuItem
        v-if="canCheckOut"
        class="cursor-pointer"
        @select="emit('checkOut', visit)"
      >
        <LogOut class="size-4" />
        {{ t('concierge.visits.actions.check_out') }}
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { EllipsisVertical, Eye, LogIn, LogOut } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import type { ConciergeVisitListItem } from '@/types/visit'

const props = defineProps<{
  visit: ConciergeVisitListItem
}>()

const emit = defineEmits<{
  checkIn: [visit: ConciergeVisitListItem]
  checkOut: [visit: ConciergeVisitListItem]
}>()

const { t } = useI18n()

const showHref = computed(() => `/concierge/visits/${props.visit.id}`)

const canShow = computed(() => props.visit.permissions.show)
const canCheckIn = computed(() => props.visit.permissions.check_in)
const canCheckOut = computed(() => props.visit.permissions.check_out)
</script>
