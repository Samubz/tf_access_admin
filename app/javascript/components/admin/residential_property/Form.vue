<template>
  <Card class="w-full">
    <CardHeader>
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <CardTitle v-if="props.title">{{ props.title }}</CardTitle>
          <CardDescription>
            {{ props.description }}
          </CardDescription>
        </div>
        <PropertyStatusBadge v-if="showStatusBadge" :status="currentStatus" />
      </div>
      <p
        v-if="props.readonly && props.readonlyReason"
        class="text-muted-foreground mt-3 text-sm"
        role="status"
      >
        {{ props.readonlyReason }}
      </p>
    </CardHeader>
    <CardContent>
      <fieldset :disabled="props.readonly || props.submitting" class="m-0 border-0 p-0">
        <form id="form-residential-property" @submit="onSubmit">
          <FieldGroup class="flex flex-col md:flex-row">
            <VeeField v-slot="{ componentField, errors }" name="name">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-name">
                  {{ t('admin.residential_properties.input.name.label') }}
                </FieldLabel>
                <Input
                  id="form-residential-property-name"
                  v-bind="componentField"
                  :placeholder="t('admin.residential_properties.input.name.placeholder')"
                  autocomplete="off"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
          </FieldGroup>
          <FieldGroup class="mt-4 flex flex-col md:flex-row">
            <VeeField v-slot="{ field, errors }" name="property_type">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-property-type">
                  {{ t('admin.residential_properties.input.property_type.label') }}
                </FieldLabel>
                <select
                  id="form-residential-property-property-type"
                  v-bind="field"
                  class="border-input bg-background ring-offset-background placeholder:text-muted-foreground focus-visible:ring-ring flex h-10 w-full rounded-md border px-3 py-2 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50"
                  :aria-invalid="!!errors.length"
                >
                  <option v-for="pt in props.propertyTypes" :key="pt" :value="pt">
                    {{ t(`admin.residential_properties.property_types.${pt}`) }}
                  </option>
                </select>
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
            <VeeField v-if="showStatusField" v-slot="{ field, errors }" name="status">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-status">
                  {{ t('admin.residential_properties.input.status.label') }}
                </FieldLabel>
                <select
                  id="form-residential-property-status"
                  v-bind="field"
                  class="border-input bg-background ring-offset-background placeholder:text-muted-foreground focus-visible:ring-ring flex h-10 w-full rounded-md border px-3 py-2 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50"
                  :aria-invalid="!!errors.length"
                >
                  <option v-for="s in EDITABLE_RESIDENTIAL_PROPERTY_STATUSES" :key="s" :value="s">
                    {{ t(`admin.residential_properties.statuses.${s}`) }}
                  </option>
                </select>
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
          </FieldGroup>
          <FieldGroup class="mt-4 flex flex-col md:flex-row">
            <VeeField v-slot="{ componentField, errors }" name="address_line">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-address">
                  {{ t('admin.residential_properties.input.address_line.label') }}
                </FieldLabel>
                <Input
                  id="form-residential-property-address"
                  v-bind="componentField"
                  :placeholder="t('admin.residential_properties.input.address_line.placeholder')"
                  autocomplete="off"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
          </FieldGroup>
          <FieldGroup class="mt-4 flex flex-col md:flex-row">
            <VeeField v-slot="{ componentField, errors }" name="city">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-city">
                  {{ t('admin.residential_properties.input.city.label') }}
                </FieldLabel>
                <Input
                  id="form-residential-property-city"
                  v-bind="componentField"
                  :placeholder="t('admin.residential_properties.input.city.placeholder')"
                  autocomplete="off"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
            <VeeField v-slot="{ componentField, errors }" name="region">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-region">
                  {{ t('admin.residential_properties.input.region.label') }}
                </FieldLabel>
                <Input
                  id="form-residential-property-region"
                  v-bind="componentField"
                  :placeholder="t('admin.residential_properties.input.region.placeholder')"
                  autocomplete="off"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
          </FieldGroup>
          <FieldGroup class="mt-4 flex flex-col md:flex-row">
            <VeeField v-slot="{ componentField, errors }" name="country">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-country">
                  {{ t('admin.residential_properties.input.country.label') }}
                </FieldLabel>
                <Input
                  id="form-residential-property-country"
                  v-bind="componentField"
                  :placeholder="t('admin.residential_properties.input.country.placeholder')"
                  autocomplete="off"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
            <VeeField v-slot="{ componentField, errors }" name="timezone">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="form-residential-property-timezone">
                  {{ t('admin.residential_properties.input.timezone.label') }}
                </FieldLabel>
                <Input
                  id="form-residential-property-timezone"
                  v-bind="componentField"
                  :placeholder="t('admin.residential_properties.input.timezone.placeholder')"
                  autocomplete="off"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
          </FieldGroup>
        </form>
      </fieldset>
    </CardContent>
    <CardFooter v-if="showActions">
      <Field orientation="horizontal" class="md:flex md:justify-end flex-col md:flex-row">
        <Button
          type="button"
          as="a"
          :href="admin_residential_properties_path()"
          variant="outline"
          class="w-full md:w-auto"
        >
          {{ props.cancelLabel || t('common.back') }}
        </Button>
        <Button
          type="submit"
          form="form-residential-property"
          class="w-full md:w-auto"
          :disabled="props.submitting"
        >
          <Loader2 v-if="props.submitting" class="mr-2 size-4 animate-spin" />
          {{ submitButtonLabel }}
        </Button>
      </Field>
    </CardFooter>
  </Card>
</template>

<script setup lang="ts">
import { computed, nextTick, watch } from 'vue'
import { toTypedSchema } from '@vee-validate/zod'
import { useForm, Field as VeeField } from 'vee-validate'
import { useI18n } from 'vue-i18n'
import { Loader2 } from 'lucide-vue-next'
import PropertyStatusBadge from '@/components/admin/residential_property/PropertyStatusBadge.vue'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  residentialPropertyCreateSchema,
  residentialPropertyEditSchema,
  EDITABLE_RESIDENTIAL_PROPERTY_STATUSES,
  PROPERTY_TYPE_VALUES,
  type ResidentialPropertyCreateSchema,
  type ResidentialPropertyEditSchema,
} from '@/lib/schemas/residential_property'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { useServerFormErrors } from '@/lib/composables/forms/useServerFormErrors'
import { admin_residential_properties_path } from '@/routes'
import type { ResidentialProperty } from '@/types/residential_property'

const props = withDefaults(
  defineProps<{
    description: string
    submitLabel: string
    propertyTypes: string[]
    mode?: 'create' | 'edit'
    title?: string
    cancelLabel?: string
    defaultValues?: ResidentialProperty
    serverErrors?: Record<string, string[]>
    readonly?: boolean
    readonlyReason?: string
    submitting?: boolean
    showActions?: boolean
  }>(),
  {
    mode: 'create',
    readonly: false,
    submitting: false,
    showActions: true,
  },
)

const emit = defineEmits<{
  (e: 'submit', data: ResidentialPropertyCreateSchema | ResidentialPropertyEditSchema): void
}>()

const { t } = useI18n()

const { translateErrors } = useTranslateErrors()
const formSchema = toTypedSchema(
  props.mode === 'create' ? residentialPropertyCreateSchema : residentialPropertyEditSchema,
)

const showStatusField = computed(() => props.mode === 'edit' && !props.readonly)
const showStatusBadge = computed(
  () => props.mode === 'edit' && props.defaultValues?.status === 'archived',
)
const currentStatus = computed(() => props.defaultValues?.status ?? 'active')
const submitButtonLabel = computed(() =>
  props.submitting ? t('admin.residential_properties.form.saving') : props.submitLabel,
)

const { handleSubmit, setErrors, resetForm } = useForm({
  validationSchema: formSchema,
  initialValues: buildInitialValues(),
})

function buildInitialValues() {
  if (props.mode === 'create') {
    return {
      name: '',
      property_type: PROPERTY_TYPE_VALUES[0],
      address_line: '',
      city: '',
      region: '',
      country: 'Chile',
      timezone: 'America/Santiago',
    }
  }

  return {
    name: '',
    property_type: PROPERTY_TYPE_VALUES[0],
    address_line: '',
    city: '',
    region: '',
    country: 'Chile',
    timezone: 'America/Santiago',
    status: 'active' as (typeof EDITABLE_RESIDENTIAL_PROPERTY_STATUSES)[number],
  }
}

function formValuesFromResidentialProperty(defaults: ResidentialProperty) {
  const pt = defaults.property_type
  const safeType =
    pt && (PROPERTY_TYPE_VALUES as readonly string[]).includes(pt)
      ? (pt as (typeof PROPERTY_TYPE_VALUES)[number])
      : PROPERTY_TYPE_VALUES[0]

  const st = defaults.status
  const safeStatus =
    st && (EDITABLE_RESIDENTIAL_PROPERTY_STATUSES as readonly string[]).includes(st)
      ? (st as (typeof EDITABLE_RESIDENTIAL_PROPERTY_STATUSES)[number])
      : 'active'

  const countryRaw = defaults.country
  const country =
    countryRaw != null && String(countryRaw).trim() !== ''
      ? String(countryRaw).trim()
      : 'Chile'

  const timezoneRaw = defaults.timezone
  const timezone =
    timezoneRaw != null && String(timezoneRaw).trim() !== ''
      ? String(timezoneRaw).trim()
      : 'America/Santiago'

  return {
    name: defaults.name ?? '',
    property_type: safeType,
    address_line: defaults.address_line ?? '',
    city: defaults.city ?? '',
    region: defaults.region ?? '',
    country,
    timezone,
    status: safeStatus,
  }
}

watch(
  () => props.defaultValues,
  (defaults) => {
    if (!defaults || props.mode !== 'edit') return
    nextTick(() => {
      resetForm({ values: formValuesFromResidentialProperty(defaults) })
    })
  },
  { immediate: true, deep: true },
)

const { applyServerErrors } = useServerFormErrors(setErrors)

watch(
  () => props.serverErrors,
  (errors) => {
    if (errors) applyServerErrors(errors)
  },
  { immediate: true, deep: true },
)

const onSubmit = handleSubmit((data) => {
  emit('submit', data)
})

defineExpose({ applyServerErrors })
</script>
