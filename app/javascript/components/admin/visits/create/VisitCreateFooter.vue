<template>
  <div class="flex w-full items-center justify-between gap-3">
    <div class="flex items-center gap-2">
      <Button v-if="showBack" type="button" variant="outline" :disabled="submitting" @click="emit('back')">
        {{ t('common.actions.back') }}
      </Button>
      <Button
        v-else-if="showCancel"
        type="button"
        variant="outline"
        :disabled="submitting"
        @click="emit('cancel')"
      >
        {{ cancelLabel ?? t('admin.visits.new.actions.cancel') }}
      </Button>
    </div>

    <div class="flex items-center gap-2">
      <Button
        v-if="primaryLabel"
        type="button"
        :disabled="primaryDisabled || submitting"
        @click="emit('primary')"
      >
        <Loader2 v-if="submitting" class="mr-2 size-4 animate-spin" aria-hidden="true" />
        {{ primaryLabel }}
      </Button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Loader2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

defineProps<{
  showBack?: boolean
  showCancel?: boolean
  cancelLabel?: string
  primaryLabel?: string
  primaryDisabled?: boolean
  submitting?: boolean
}>()

const emit = defineEmits<{
  (e: 'back'): void
  (e: 'cancel'): void
  (e: 'primary'): void
}>()

const { t } = useI18n()
</script>
