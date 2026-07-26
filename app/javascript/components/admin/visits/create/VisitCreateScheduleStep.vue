<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <h3 class="text-base font-semibold">{{ t('admin.visits.new.schedule.title') }}</h3>
      <p class="text-sm text-muted-foreground">{{ t('admin.visits.new.schedule.description') }}</p>
    </div>

    <FieldGroup class="grid gap-4 md:grid-cols-3">
      <Field>
        <FieldLabel for="visit-date">{{ t('admin.visits.new.schedule.fields.date') }}</FieldLabel>
        <Input
          id="visit-date"
          v-model="form.visit_date"
          type="date"
          :aria-invalid="!!fieldErrors.visit_date"
        />
        <FieldError v-if="fieldErrors.visit_date" :errors="translateErrors([fieldErrors.visit_date])" />
      </Field>

      <Field>
        <FieldLabel for="visit-start-time">{{ t('admin.visits.new.schedule.fields.start_time') }}</FieldLabel>
        <Input
          id="visit-start-time"
          v-model="form.start_time"
          type="time"
          :aria-invalid="!!fieldErrors.start_time"
        />
        <FieldError v-if="fieldErrors.start_time" :errors="translateErrors([fieldErrors.start_time])" />
      </Field>

      <Field>
        <FieldLabel for="visit-end-time">{{ t('admin.visits.new.schedule.fields.end_time') }}</FieldLabel>
        <Input
          id="visit-end-time"
          v-model="form.end_time"
          type="time"
          :aria-invalid="!!fieldErrors.end_time"
        />
        <FieldError v-if="fieldErrors.end_time" :errors="translateErrors([fieldErrors.end_time])" />
        <p class="text-xs text-muted-foreground">{{ t('admin.visits.new.schedule.end_time_hint') }}</p>
      </Field>
    </FieldGroup>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import type { VisitCreateForm } from '@/lib/schemas/visit_create'

const form = defineModel<VisitCreateForm>('form', { required: true })

const props = defineProps<{
  fieldErrors?: Record<string, string | undefined>
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const fieldErrors = computed(() => props.fieldErrors ?? {})

function pad(value: number) {
  return String(value).padStart(2, '0')
}

// Defaults blank date/time to the browser's exact current local date/time on
// first render of a new empty form (improve-admin-visit-form-inputs, design.md
// Decision 5). Restored session state or user-entered values are never blank
// here, so they are never overwritten. `end_time` is intentionally left as-is.
onMounted(() => {
  const now = new Date()
  if (!form.value.visit_date) {
    form.value.visit_date = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
  }
  if (!form.value.start_time) {
    form.value.start_time = `${pad(now.getHours())}:${pad(now.getMinutes())}`
  }
})
</script>
