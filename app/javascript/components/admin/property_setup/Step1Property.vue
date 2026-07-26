<template>
  <form class="space-y-4" @submit.prevent>
    <FieldGroup class="grid gap-4 md:grid-cols-2">
      <Field :data-invalid="!!fieldError('name')">
        <FieldLabel>{{ t('admin.property_setup.step1.fields.name') }}</FieldLabel>
        <Input v-model="form.name" :aria-invalid="!!fieldError('name')" />
        <FieldError v-if="fieldError('name')" :errors="translateErrors([fieldError('name')])" />
      </Field>
      <Field :data-invalid="!!fieldError('property_type')">
        <FieldLabel>{{ t('admin.property_setup.step1.fields.property_type') }}</FieldLabel>
        <select
          v-model="form.property_type"
          class="border-input bg-background flex h-10 w-full rounded-md border px-3 py-2 text-sm"
          :aria-invalid="!!fieldError('property_type')"
        >
          <option v-for="pt in propertyTypes" :key="pt" :value="pt">
            {{ t(`admin.residential_properties.property_types.${pt}`) }}
          </option>
        </select>
        <FieldError
          v-if="fieldError('property_type')"
          :errors="translateErrors([fieldError('property_type')])"
        />
      </Field>
    </FieldGroup>
    <Field :data-invalid="!!fieldError('address_line')">
      <FieldLabel>{{ t('admin.property_setup.step1.fields.address') }}</FieldLabel>
      <Input v-model="form.address_line" :aria-invalid="!!fieldError('address_line')" />
      <FieldError
        v-if="fieldError('address_line')"
        :errors="translateErrors([fieldError('address_line')])"
      />
    </Field>
    <FieldGroup class="grid gap-4 md:grid-cols-2">
      <Field>
        <FieldLabel>{{ t('admin.property_setup.step1.fields.city') }}</FieldLabel>
        <Input v-model="form.city" />
      </Field>
    </FieldGroup>
  </form>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Input } from '@/components/ui/input'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { usePropertySetupStepValidation } from '@/lib/composables/property_setup/usePropertySetupStepValidation'
import type { PropertySetupStep1Values } from '@/lib/schemas/property_setup'

const props = defineProps<{
  propertyTypes: string[]
  initialValues: Record<string, unknown>
  errors?: Record<string, string[]>
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const { fieldError, validateStep1, setFieldErrors } = usePropertySetupStepValidation()

const form = reactive({
  name: '',
  property_type: '',
  address_line: '',
  city: '',
  region: '',
  country: 'Chile',
  timezone: 'America/Santiago',
})

watch(
  () => props.initialValues,
  (values) => {
    Object.assign(form, values)
  },
  { immediate: true, deep: true },
)

watch(
  () => props.errors,
  (errors) => {
    if (!errors) return
    const mapped = Object.fromEntries(
      Object.entries(errors).map(([key, messages]) => [key, messages[0]]),
    )
    setFieldErrors(mapped)
  },
  { immediate: true, deep: true },
)

const preview = computed(() => ({
  property_type: form.property_type,
  city: form.city,
}))

function getValues() {
  return { ...form }
}

function validate() {
  return validateStep1(getValues() as PropertySetupStep1Values)
}

defineExpose({ getValues, preview, validate })
</script>
