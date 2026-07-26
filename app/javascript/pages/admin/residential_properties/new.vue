<template>
  <div>
    <Header :itemsBreadcrumb="itemsBreadcrumb" :title="t('admin.residential_properties.new.title')" />
    <Form
      ref="formRef"
      mode="create"
      :description="t('admin.residential_properties.new.description')"
      :submitLabel="t('admin.residential_properties.new.submit')"
      :property-types="props.property_types"
      :server-errors="props.errors"
      :submitting="isSubmitting"
      @submit="submitCreate"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import Header from '@/components/admin/layout/Header.vue'
import { getResidentialPropertiesBreadcrumbs } from '@/lib/breadcrumbs/residential_property'
import Form from '@/components/admin/residential_property/Form.vue'
import { useResidentialPropertySubmit } from '@/lib/composables/residential_property/useResidentialPropertySubmit'
import { applyErrorsToFormRef } from '@/lib/composables/forms/apply_errors_to_form_ref'

const { t } = useI18n()

const props = defineProps<{
  property_types: string[]
  errors?: Record<string, string[]>
}>()

const formRef = ref<InstanceType<typeof Form> | null>(null)
const itemsBreadcrumb = computed(() => getResidentialPropertiesBreadcrumbs(t))
const { isSubmitting, submitCreate } = useResidentialPropertySubmit(formRef)

onMounted(() => {
  if (!props.errors || Object.keys(props.errors).length === 0) return
  applyErrorsToFormRef(formRef, props.errors)
  toast.error(t('admin.residential_properties.creation_failed'))
})
</script>
