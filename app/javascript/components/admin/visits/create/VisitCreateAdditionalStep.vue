<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <h3 class="text-base font-semibold">{{ t('admin.visits.new.additional.title') }}</h3>
      <p class="text-sm text-muted-foreground">{{ t('admin.visits.new.additional.description') }}</p>
    </div>

    <FieldGroup class="grid gap-4 md:grid-cols-2">
      <Field class="md:col-span-2">
        <FieldLabel for="visit-type">{{ t('admin.visits.new.additional.fields.reason') }}</FieldLabel>
        <NativeSelect
          id="visit-type"
          v-model="form.visit_type"
          class="w-full"
          :aria-invalid="!!fieldErrors.visit_type"
        >
          <NativeSelectOption value="">
            {{ t('admin.visits.new.additional.placeholders.reason') }}
          </NativeSelectOption>
          <NativeSelectOption v-for="type in visitTypes" :key="type.value" :value="type.value">
            {{ type.label }}
          </NativeSelectOption>
        </NativeSelect>
        <FieldError v-if="fieldErrors.visit_type" :errors="translateErrors([fieldErrors.visit_type])" />
      </Field>

      <Field>
        <FieldLabel for="visit-vehicle-plate">
          {{ t('admin.visits.new.additional.fields.vehicle_plate') }}
        </FieldLabel>
        <Input
          id="visit-vehicle-plate"
          v-model="form.vehicle.plate"
          :placeholder="t('admin.visits.new.additional.placeholders.vehicle_plate')"
        />
      </Field>

      <Field>
        <FieldLabel for="visit-vehicle-model">
          {{ t('admin.visits.new.additional.fields.vehicle_model') }}
        </FieldLabel>
        <Input
          id="visit-vehicle-model"
          v-model="form.vehicle.brand_model"
          :placeholder="t('admin.visits.new.additional.placeholders.vehicle_model')"
        />
      </Field>

      <Field class="md:col-span-2">
        <FieldLabel for="visit-vehicle-color">
          {{ t('admin.visits.new.additional.fields.vehicle_color') }}
        </FieldLabel>
        <Input
          id="visit-vehicle-color"
          v-model="form.vehicle.color"
          :placeholder="t('admin.visits.new.additional.placeholders.vehicle_color')"
        />
      </Field>
    </FieldGroup>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { NativeSelect, NativeSelectOption } from '@/components/ui/native-select'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import type { VisitCreateForm, VisitTypeOption } from '@/lib/schemas/visit_create'

const form = defineModel<VisitCreateForm>('form', { required: true })

const props = defineProps<{
  visitTypes: VisitTypeOption[]
  fieldErrors?: Record<string, string | undefined>
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const fieldErrors = computed(() => props.fieldErrors ?? {})
</script>
