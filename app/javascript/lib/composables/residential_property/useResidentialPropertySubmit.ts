import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import { applyErrorsToFormRef } from '@/lib/composables/forms/apply_errors_to_form_ref'
import type { ExposedFormWithServerErrors } from '@/lib/composables/forms/useServerFormErrors'
import type {
  ResidentialPropertyCreateSchema,
  ResidentialPropertyEditSchema,
} from '@/lib/schemas/residential_property'
import type { Ref } from 'vue'

type FormRef = Ref<ExposedFormWithServerErrors | null | undefined>

export function useResidentialPropertySubmit(formRef: FormRef) {
  const { t } = useI18n()
  const isSubmitting = ref(false)

  function submitCreate(data: ResidentialPropertyCreateSchema) {
    isSubmitting.value = true
    router.post(
      '/admin/residential_properties',
      {
        residential_property: {
          name: data.name,
          property_type: data.property_type,
          address_line: data.address_line,
          city: data.city,
          region: data.region,
          country: data.country,
          timezone: data.timezone,
        },
      },
      {
        preserveScroll: true,
        preserveState: true,
        onSuccess: () => toast.success(t('admin.residential_properties.created_successfully')),
        onError: (errors) => {
          toast.error(t('admin.residential_properties.creation_failed'))
          applyErrorsToFormRef(formRef, errors)
        },
        onFinish: () => {
          isSubmitting.value = false
        },
      },
    )
  }

  function submitUpdate(propertyId: string, data: ResidentialPropertyEditSchema) {
    isSubmitting.value = true
    router.put(
      `/admin/residential_properties/${propertyId}`,
      {
        residential_property: {
          name: data.name,
          property_type: data.property_type,
          address_line: data.address_line,
          city: data.city,
          region: data.region,
          country: data.country,
          timezone: data.timezone,
          status: data.status,
        },
      },
      {
        preserveScroll: true,
        preserveState: true,
        onSuccess: () => {
          toast.success(t('admin.residential_properties.updated_successfully'))
          router.reload({ only: ['residential_property'] })
        },
        onError: (errors) => {
          toast.error(t('admin.residential_properties.update_failed'))
          applyErrorsToFormRef(formRef, errors)
        },
        onFinish: () => {
          isSubmitting.value = false
        },
      },
    )
  }

  function submitArchive(propertyId: string, options?: { onFinish?: () => void }) {
    router.post(
      `/admin/residential_properties/${propertyId}/archive`,
      {},
      {
        onSuccess: () => {
          toast.success(t('admin.residential_properties.index.actions.archive_success'))
        },
        onError: () => {
          toast.error(t('admin.residential_properties.index.actions.archive_error'))
        },
        onFinish: () => {
          options?.onFinish?.()
        },
      },
    )
  }

  return {
    isSubmitting,
    submitCreate,
    submitUpdate,
    submitArchive,
  }
}
