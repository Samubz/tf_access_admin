<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <h3 class="text-base font-semibold">{{ t('admin.visits.new.confirm.title') }}</h3>
      <p class="text-sm text-muted-foreground">{{ t('admin.visits.new.confirm.description') }}</p>
    </div>

    <Field>
      <FieldLabel for="visit-notes">{{ t('admin.visits.new.confirm.fields.notes') }}</FieldLabel>
      <Textarea
        id="visit-notes"
        v-model="form.notes"
        rows="4"
        :placeholder="t('admin.visits.new.confirm.placeholders.notes')"
      />
    </Field>

    <FieldError v-if="fieldErrors.base" :errors="translateErrors([fieldErrors.base])" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Field, FieldError, FieldLabel } from '@/components/ui/field'
import { Textarea } from '@/components/ui/textarea'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import type { VisitCreateForm } from '@/lib/schemas/visit_create'

const form = defineModel<VisitCreateForm>('form', { required: true })

const props = defineProps<{
  fieldErrors?: Record<string, string | undefined>
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const fieldErrors = computed(() => props.fieldErrors ?? {})
</script>
