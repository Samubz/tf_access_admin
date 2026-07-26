<template>
  <Drawer v-model:open="open" direction="right" @update:open="onOpenChange">
    <DrawerContent
      class="flex h-full max-h-screen flex-col data-[vaul-drawer-direction=right]:w-full data-[vaul-drawer-direction=right]:sm:max-w-xl"
    >
      <DrawerHeader class="shrink-0 border-b pb-4">
        <div class="flex items-start justify-between gap-4">
          <div>
            <DrawerTitle>{{ t('concierge.visits.check_in.title') }}</DrawerTitle>
            <DrawerDescription>{{ t('concierge.visits.check_in.description') }}</DrawerDescription>
          </div>
          <DrawerClose as-child>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              :aria-label="t('common.actions.cancel')"
            >
              <X class="size-4" />
            </Button>
          </DrawerClose>
        </div>
      </DrawerHeader>

      <div v-if="visit" class="flex-1 space-y-5 overflow-y-auto px-4 py-5">
        <VisitOperationalSummary :visit="visit" />

        <div class="space-y-4">
          <div class="space-y-2">
            <Label for="check-in-time">{{ t('concierge.visits.check_in.fields.entry_time') }}</Label>
            <Input id="check-in-time" :model-value="currentDateTime" readonly />
          </div>

          <div class="space-y-2">
            <Label for="check-in-access-point">{{ t('concierge.visits.check_in.fields.access_point') }}</Label>
            <NativeSelect id="check-in-access-point" v-model="form.access_point" class="w-full">
              <NativeSelectOption value="">
                {{ t('concierge.visits.check_in.fields.select_access_point') }}
              </NativeSelectOption>
              <NativeSelectOption v-for="point in accessPoints" :key="point" :value="point">
                {{ t(`concierge.visits.access_points.${point}`) }}
              </NativeSelectOption>
            </NativeSelect>
          </div>

          <div class="space-y-2">
            <Label for="check-in-access-type">{{ t('concierge.visits.check_in.fields.access_type') }}</Label>
            <NativeSelect id="check-in-access-type" v-model="form.access_type" class="w-full">
              <NativeSelectOption value="">
                {{ t('concierge.visits.check_in.fields.select_access_type') }}
              </NativeSelectOption>
              <NativeSelectOption v-for="type in accessTypes" :key="type" :value="type">
                {{ t(`concierge.visits.access_types.${type}`) }}
              </NativeSelectOption>
            </NativeSelect>
          </div>

          <div class="space-y-2">
            <Label for="check-in-vehicle">{{ t('concierge.visits.check_in.fields.vehicle_plate') }}</Label>
            <Input
              id="check-in-vehicle"
              v-model="form.vehicle_plate"
              :placeholder="t('concierge.visits.check_in.fields.vehicle_plate_placeholder')"
            />
          </div>

          <div class="space-y-2">
            <Label for="check-in-notes">{{ t('concierge.visits.check_in.fields.notes') }}</Label>
            <Textarea
              id="check-in-notes"
              v-model="form.notes"
              :maxlength="notesMaxLength"
              rows="3"
            />
            <p class="text-muted-foreground text-xs">
              {{ form.notes.length }}/{{ notesMaxLength }}
            </p>
          </div>
        </div>

        <div class="rounded-lg border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-900">
          {{ t('concierge.visits.check_in.info_banner') }}
        </div>

        <div v-if="errors.length" class="rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3">
          <p v-for="error in errors" :key="error" class="text-destructive text-sm">{{ error }}</p>
        </div>
      </div>

      <DrawerFooter class="shrink-0 border-t px-4 py-4">
        <div class="flex w-full justify-end gap-2">
          <Button type="button" variant="outline" :disabled="submitting" @click="open = false">
            {{ t('common.actions.cancel') }}
          </Button>
          <Button type="button" :disabled="submitting || !canSubmit" @click="confirm">
            <Loader2 v-if="submitting" class="size-4 animate-spin" />
            <Check v-else class="size-4" />
            {{ t('concierge.visits.check_in.confirm') }}
          </Button>
        </div>
      </DrawerFooter>
    </DrawerContent>
  </Drawer>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check, Loader2, X } from 'lucide-vue-next'
import VisitOperationalSummary from '@/components/concierge/visits/VisitOperationalSummary.vue'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
} from '@/components/ui/drawer'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { NativeSelect, NativeSelectOption } from '@/components/ui/native-select'
import { Textarea } from '@/components/ui/textarea'
import { useVisitOperationalSubmit } from '@/lib/composables/concierge/useVisitOperationalSubmit'
import {
  VISIT_ACCESS_POINTS,
  VISIT_ACCESS_TYPES,
  VISIT_NOTES_MAX_LENGTH,
} from '@/lib/constants/visit_operational'
import type { ConciergeVisitListItem } from '@/types/visit'

const props = defineProps<{
  visit: ConciergeVisitListItem | null
  returnTo?: 'list' | 'detail'
  namespace?: 'admin' | 'concierge'
}>()

const open = defineModel<boolean>('open', { default: false })

const emit = defineEmits<{
  success: []
}>()

const { t, locale } = useI18n()
const accessPoints = VISIT_ACCESS_POINTS
const accessTypes = VISIT_ACCESS_TYPES
const notesMaxLength = VISIT_NOTES_MAX_LENGTH

const form = reactive({
  access_point: VISIT_ACCESS_POINTS[0],
  access_type: VISIT_ACCESS_TYPES[0],
  vehicle_plate: '',
  notes: '',
})

const { submitting, errors, submitCheckIn } = useVisitOperationalSubmit({
  returnTo: props.returnTo ?? 'list',
  namespace: props.namespace ?? 'concierge',
})

const currentDateTime = computed(() =>
  new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date()),
)

const canSubmit = computed(() => Boolean(form.access_point && form.access_type))

watch(open, (isOpen) => {
  if (!isOpen) return
  resetForm()
})

function resetForm() {
  form.access_point = VISIT_ACCESS_POINTS[0]
  form.access_type = VISIT_ACCESS_TYPES[0]
  form.vehicle_plate = ''
  form.notes = ''
  errors.value = []
}

function onOpenChange(value: boolean) {
  open.value = value
}

function confirm() {
  if (!props.visit || !canSubmit.value) return

  submitCheckIn(
    props.visit,
    {
      access_point: form.access_point,
      access_type: form.access_type,
      vehicle_plate: form.vehicle_plate.trim() || undefined,
      notes: form.notes.trim() || undefined,
    },
    () => {
      open.value = false
      emit('success')
    },
  )
}
</script>
