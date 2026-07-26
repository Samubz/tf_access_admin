<template>
  <div>
    <Header :items-breadcrumb="itemsBreadcrumb" :title="t('admin.visits.new.title')" />

    <p class="text-muted-foreground mb-6 max-w-3xl text-sm">
      {{ t('admin.visits.new.description') }}
    </p>

    <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_320px]">
      <div class="rounded-xl border bg-card">
        <div class="border-b px-4 py-4 sm:px-6">
          <VisitCreateStepper :step-index="stepIndex" />
        </div>

        <div class="space-y-6 px-4 py-6 sm:px-6">
          <VisitCreateGeneralStep
            v-if="currentStep === 'general'"
            v-model:form="form"
            :field-errors="fieldErrors"
            :lock-property-unit="isContextualCreate"
            @unit-change="handleUnitChange"
          />

          <VisitCreateVisitorStep
            v-else-if="currentStep === 'visitor'"
            v-model:form="form"
            :field-errors="fieldErrors"
            @visitor-selected="visitorDisplayName = $event"
          />

          <VisitCreateScheduleStep
            v-else-if="currentStep === 'schedule'"
            v-model:form="form"
            :field-errors="fieldErrors"
          />

          <VisitCreateAdditionalStep
            v-else-if="currentStep === 'additional'"
            v-model:form="form"
            :visit-types="visitTypes"
            :field-errors="fieldErrors"
          />

          <VisitCreateConfirmStep
            v-else-if="currentStep === 'confirm'"
            v-model:form="form"
            :field-errors="fieldErrors"
          />
        </div>

        <div class="border-t px-4 py-4 sm:px-6">
          <VisitCreateFooter
            :show-back="stepIndex > 0"
            :show-cancel="stepIndex === 0"
            :primary-label="primaryActionLabel"
            :primary-disabled="false"
            :submitting="submitting"
            @back="handleBack"
            @cancel="handleCancel"
            @primary="handlePrimary"
          />
        </div>
      </div>

      <VisitAuthorizationSummary
        :visit-types="visitTypes"
        :property-name="form.residential_property_name"
        :unit-label="form.unit_label"
        :visitor-name="resolvedVisitorName"
        :visit-type="form.visit_type"
        :visit-date="form.visit_date"
        :start-time="form.start_time"
        :end-time="form.end_time"
        :vehicle-plate="form.vehicle.plate"
        :vehicle-brand-model="form.vehicle.brand_model"
        :initial-status-preview="initialStatusPreview"
        :status-loading="statusLoading"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { router } from '@inertiajs/vue3'
import Header from '@/components/admin/layout/Header.vue'
import VisitAuthorizationSummary from '@/components/admin/visits/create/VisitAuthorizationSummary.vue'
import VisitCreateAdditionalStep from '@/components/admin/visits/create/VisitCreateAdditionalStep.vue'
import VisitCreateConfirmStep from '@/components/admin/visits/create/VisitCreateConfirmStep.vue'
import VisitCreateFooter from '@/components/admin/visits/create/VisitCreateFooter.vue'
import VisitCreateGeneralStep from '@/components/admin/visits/create/VisitCreateGeneralStep.vue'
import VisitCreateScheduleStep from '@/components/admin/visits/create/VisitCreateScheduleStep.vue'
import VisitCreateStepper from '@/components/admin/visits/create/VisitCreateStepper.vue'
import VisitCreateVisitorStep from '@/components/admin/visits/create/VisitCreateVisitorStep.vue'
import {
  clearVisitCreateState,
  loadVisitCreateState,
  saveVisitCreateState,
  useAdminVisitCreate,
} from '@/lib/composables/admin/useAdminVisitCreate'
import { useAdminVisitFormData } from '@/lib/composables/admin/useAdminVisitFormData'
import { mapServerErrorsToForm } from '@/lib/forms/map_server_errors'
import { buildDisplayName } from '@/lib/schemas/unit_ownership'
import type { VisitTypeOption } from '@/lib/schemas/visit_create'
import { admin_residential_property_unit_path, admin_visits_path } from '@/routes'
import type { VisitContextualCreateContext } from '@/types/visit'

const props = defineProps<{
  visit_types: VisitTypeOption[]
  contextual?: VisitContextualCreateContext
  errors?: Record<string, string[]>
}>()

const { t } = useI18n()
const submitting = ref(false)
const clientFieldErrors = ref<Record<string, string | undefined>>({})
const visitorDisplayName = ref('')

const defaultVisitType = props.visit_types[0]?.value ?? 'guest'

const {
  currentStep,
  form,
  stepIndex,
  snapshot,
  restoreSnapshot,
  goNext,
  goBack,
  validateStep,
  buildSubmitPayload,
} = useAdminVisitCreate(defaultVisitType)

const { initialStatusPreview, statusLoading, fetchInitialStatusPreview } = useAdminVisitFormData()

const isContextualCreate = computed(() => Boolean(props.contextual?.unit))

const itemsBreadcrumb = computed(() => {
  if (isContextualCreate.value && props.contextual?.unit) {
    const unit = props.contextual.unit
    return [
      {
        label: unit.display_name ?? unit.identifier,
        href: admin_residential_property_unit_path(unit.residential_property_id, unit.id, {
          tab: 'visits',
        }),
      },
      { label: t('admin.visits.new.title') },
    ]
  }

  return [
    { label: t('admin.sidebar.manage_visits'), href: admin_visits_path() },
    { label: t('admin.visits.new.title') },
  ]
})

const visitTypes = computed(() => props.visit_types)

const serverFieldErrors = computed(() =>
  props.errors ? mapVisitCreateServerErrors(props.errors) : {},
)

const fieldErrors = computed(() => ({
  ...serverFieldErrors.value,
  ...clientFieldErrors.value,
}))

const resolvedVisitorName = computed(() => {
  if (form.value.visitor_mode === 'create') {
    return (
      visitorDisplayName.value ||
      buildDisplayName(form.value.visitor.first_name, form.value.visitor.last_name)
    )
  }
  return visitorDisplayName.value
})

const primaryActionLabel = computed(() => {
  if (currentStep.value === 'confirm') {
    return t('admin.visits.new.actions.submit')
  }
  return t('admin.visits.new.actions.continue')
})

async function handleUnitChange(unitId: string) {
  await fetchInitialStatusPreview(unitId)
}

function handleBack() {
  clientFieldErrors.value = {}
  goBack()
}

function handleCancel() {
  if (isContextualCreate.value && props.contextual?.unit) {
    const unit = props.contextual.unit
    router.visit(
      admin_residential_property_unit_path(unit.residential_property_id, unit.id, { tab: 'visits' }),
    )
    return
  }

  router.visit(admin_visits_path())
}

function handlePrimary() {
  clientFieldErrors.value = {}
  const errors = validateStep(currentStep.value)
  if (Object.keys(errors).length > 0) {
    clientFieldErrors.value = errors
    return
  }

  if (currentStep.value === 'confirm') {
    submit()
    return
  }

  goNext()
}

function submit() {
  submitting.value = true
  saveVisitCreateState(snapshot())

  const payload = buildSubmitPayload()
  if (isContextualCreate.value && props.contextual?.unit) {
    payload.return_to = 'unit'
    payload.context = {
      unit_id: props.contextual.unit.id,
      return_to: 'unit',
    }
  }

  router.post('/admin/visits', payload, {
    preserveScroll: true,
    onFinish: () => {
      submitting.value = false
    },
    onSuccess: () => {
      clearVisitCreateState()
    },
  })
}

function restoreFromServerErrors() {
  const state = loadVisitCreateState()
  if (!state) return

  restoreSnapshot(state)
  currentStep.value = 'confirm'
  if (state.form.unit_id) void fetchInitialStatusPreview(state.form.unit_id)
}

function mapVisitCreateServerErrors(errors: Record<string, string[]>) {
  const mapped = mapServerErrorsToForm(errors)
  ;['document_number', 'first_name', 'last_name', 'phone', 'display_name', 'email'].forEach((key) => {
    if (mapped[key]) {
      mapped[`visitor.${key}`] = mapped[key]
      delete mapped[key]
    }
  })
  return mapped
}

watch(
  () => props.errors,
  (errors) => {
    if (errors && Object.keys(errors).length > 0) {
      restoreFromServerErrors()
    }
  },
  { immediate: true },
)

async function initializeContextualCreate() {
  if (!props.contextual?.unit) return

  const unit = props.contextual.unit
  form.value.residential_property_id = unit.residential_property_id
  form.value.residential_property_name = unit.property_name
  form.value.unit_id = unit.id
  form.value.unit_label = unit.display_name ?? unit.identifier
  await fetchInitialStatusPreview(unit.id)
}

onMounted(() => {
  void initializeContextualCreate()
})
</script>
