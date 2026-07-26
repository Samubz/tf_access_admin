<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <h3 class="text-base font-semibold">{{ t('admin.visits.new.general.title') }}</h3>
      <p class="text-sm text-muted-foreground">{{ t('admin.visits.new.general.description') }}</p>
    </div>

    <FieldGroup class="grid gap-4 md:grid-cols-2">
      <Field>
        <FieldLabel for="visit-property">{{ t('admin.visits.new.general.fields.property') }}</FieldLabel>
        <AsyncSearchableSelect
          id="visit-property"
          :key="`property-${lockPropertyUnit}`"
          v-model="form.residential_property_id"
          :load-options="loadProperties"
          :selected-option="propertySelectedOption"
          :placeholder="t('admin.visits.new.general.placeholders.property')"
          :disabled="lockPropertyUnit"
          :invalid="!!fieldErrors.residential_property_id"
          @option-selected="onPropertySelected"
        />
        <FieldError
          v-if="fieldErrors.residential_property_id"
          :errors="translateErrors([fieldErrors.residential_property_id])"
        />
      </Field>

      <Field>
        <FieldLabel for="visit-unit">{{ t('admin.visits.new.general.fields.unit') }}</FieldLabel>
        <AsyncSearchableSelect
          id="visit-unit"
          :key="`unit-${lockPropertyUnit}-${form.residential_property_id}`"
          v-model="form.unit_id"
          :load-options="loadUnits"
          :selected-option="unitSelectedOption"
          :placeholder="t('admin.visits.new.general.placeholders.unit')"
          :empty-text="t('admin.visits.new.general.empty.units')"
          :disabled="lockPropertyUnit || !form.residential_property_id"
          :invalid="!!fieldErrors.unit_id"
          @option-selected="onUnitSelected"
        />
        <FieldError v-if="fieldErrors.unit_id" :errors="translateErrors([fieldErrors.unit_id])" />
      </Field>
    </FieldGroup>
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { AsyncSearchableSelect } from '@/components/ui/searchable-select'
import type { SearchableSelectLoader, SearchableSelectOption } from '@/components/ui/searchable-select'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import type { VisitCreateForm } from '@/lib/schemas/visit_create'

const form = defineModel<VisitCreateForm>('form', { required: true })

const props = defineProps<{
  fieldErrors?: Record<string, string | undefined>
  lockPropertyUnit?: boolean
}>()

const emit = defineEmits<{
  (e: 'property-change', propertyId: string): void
  (e: 'unit-change', unitId: string): void
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const { railsFetchJson } = useRailsFetch()
const fieldErrors = computed(() => props.fieldErrors ?? {})
const lockPropertyUnit = computed(() => props.lockPropertyUnit ?? false)

const propertySelectedOption = computed<SearchableSelectOption | null>(() =>
  form.value.residential_property_id
    ? { value: form.value.residential_property_id, label: form.value.residential_property_name }
    : null,
)

const unitSelectedOption = computed<SearchableSelectOption | null>(() =>
  form.value.unit_id ? { value: form.value.unit_id, label: form.value.unit_label } : null,
)

const loadProperties: SearchableSelectLoader = async ({ query, page }) => {
  const params = new URLSearchParams({ page: String(page) })
  if (query) params.set('search', query)

  const { res, data } = await railsFetchJson<{
    properties: { id: string; name: string }[]
    pagination: { has_more: boolean }
  }>('GET', `/admin/visits/form_properties?${params.toString()}`)

  if (!res.ok) throw new Error('form_properties_failed')

  return {
    options: data.properties.map((property) => ({ value: property.id, label: property.name })),
    hasMore: data.pagination.has_more,
  }
}

const loadUnits: SearchableSelectLoader = async ({ query, page }) => {
  if (!form.value.residential_property_id) return { options: [], hasMore: false }

  const params = new URLSearchParams({
    page: String(page),
    residential_property_id: form.value.residential_property_id,
  })
  if (query) params.set('search', query)

  const { res, data } = await railsFetchJson<{
    units: { id: string; identifier: string; display_name: string | null }[]
    pagination: { has_more: boolean }
  }>('GET', `/admin/visits/form_units?${params.toString()}`)

  if (!res.ok) throw new Error('form_units_failed')

  return {
    options: data.units.map((unit) => ({
      value: unit.id,
      label: unit.display_name ?? unit.identifier,
    })),
    hasMore: data.pagination.has_more,
  }
}

function onPropertySelected(option: SearchableSelectOption | null) {
  form.value.residential_property_name = option?.label ?? ''
}

function onUnitSelected(option: SearchableSelectOption | null) {
  form.value.unit_label = option?.label ?? ''
}

watch(
  () => form.value.residential_property_id,
  (propertyId, previousPropertyId) => {
    if (lockPropertyUnit.value) return
    if (propertyId === previousPropertyId) return
    form.value.unit_id = ''
    form.value.unit_label = ''
    emit('property-change', String(propertyId ?? ''))
  },
)

watch(
  () => form.value.unit_id,
  (unitId, previousUnitId) => {
    if (lockPropertyUnit.value) return
    if (unitId === previousUnitId) return
    emit('unit-change', String(unitId ?? ''))
  },
)
</script>
