import { computed, ref } from 'vue'
import {
  VISIT_CREATE_STEPS,
  createEmptyVisitCreateForm,
  visitCreateAdditionalSchema,
  visitCreateGeneralSchema,
  visitCreatePersonSchema,
  visitCreateScheduleSchema,
  type VisitCreateForm,
  type VisitCreateStep,
  type VisitCreateSubmitPayload,
} from '@/lib/schemas/visit_create'

const DRAWER_STATE_KEY = 'adminVisitCreateFormState'

export type VisitCreateFormSnapshot = {
  currentStep: VisitCreateStep
  form: VisitCreateForm
}

export function saveVisitCreateState(snapshot: VisitCreateFormSnapshot) {
  sessionStorage.setItem(DRAWER_STATE_KEY, JSON.stringify(snapshot))
}

export function loadVisitCreateState(): VisitCreateFormSnapshot | null {
  const raw = sessionStorage.getItem(DRAWER_STATE_KEY)
  if (!raw) return null

  try {
    return JSON.parse(raw) as VisitCreateFormSnapshot
  } catch {
    return null
  }
}

export function clearVisitCreateState() {
  sessionStorage.removeItem(DRAWER_STATE_KEY)
}

export function useAdminVisitCreate(defaultVisitType = 'guest') {
  const currentStep = ref<VisitCreateStep>('general')
  const form = ref<VisitCreateForm>(createEmptyVisitCreateForm(defaultVisitType))

  const stepIndex = computed(() => VISIT_CREATE_STEPS.indexOf(currentStep.value))

  function snapshot(): VisitCreateFormSnapshot {
    return {
      currentStep: currentStep.value,
      form: { ...form.value, visitor: { ...form.value.visitor }, vehicle: { ...form.value.vehicle } },
    }
  }

  function restoreSnapshot(state: VisitCreateFormSnapshot) {
    currentStep.value = state.currentStep
    form.value = {
      ...state.form,
      visitor: { ...state.form.visitor },
      vehicle: { ...state.form.vehicle },
    }
  }

  function resetForm(defaultType = defaultVisitType) {
    currentStep.value = 'general'
    form.value = createEmptyVisitCreateForm(defaultType)
  }

  function goNext() {
    const index = stepIndex.value
    if (index < VISIT_CREATE_STEPS.length - 1) {
      currentStep.value = VISIT_CREATE_STEPS[index + 1]!
    }
  }

  function goBack() {
    const index = stepIndex.value
    if (index > 0) {
      currentStep.value = VISIT_CREATE_STEPS[index - 1]!
    }
  }

  function validateStep(step: VisitCreateStep): Record<string, string | undefined> {
    if (step === 'general') {
      const result = visitCreateGeneralSchema.safeParse(form.value)
      if (result.success) return {}
      return mapZodErrors(result.error)
    }

    if (step === 'visitor') {
      if (form.value.visitor_mode === 'search') {
        return form.value.visitor_person_id
          ? {}
          : { visitor_person_id: 'admin.visits.new.validations.visitor_required' }
      }

      const result = visitCreatePersonSchema.safeParse(form.value.visitor)
      if (result.success) return {}
      return prefixErrors(mapZodErrors(result.error), 'visitor.')
    }

    if (step === 'schedule') {
      const result = visitCreateScheduleSchema.safeParse(form.value)
      if (result.success) {
        if (form.value.end_time && form.value.start_time && form.value.end_time < form.value.start_time) {
          return { end_time: 'admin.visits.new.validations.end_time_before_start' }
        }
        return {}
      }
      return mapZodErrors(result.error)
    }

    if (step === 'additional') {
      const result = visitCreateAdditionalSchema.safeParse(form.value)
      if (result.success) return {}
      return mapZodErrors(result.error)
    }

    return {}
  }

  function buildSubmitPayload(): VisitCreateSubmitPayload {
    const scheduledAt = combineDateAndTime(form.value.visit_date, form.value.start_time)
    const validUntil = form.value.end_time
      ? combineDateAndTime(form.value.visit_date, form.value.end_time)
      : undefined

    const visit: VisitCreateSubmitPayload['visit'] = {
      unit_id: form.value.unit_id,
      scheduled_at: scheduledAt,
      valid_from: scheduledAt,
      valid_until: validUntil,
      visit_type: form.value.visit_type,
      notes: form.value.notes || undefined,
    }

    const payload: VisitCreateSubmitPayload = { visit }

    if (form.value.visitor_mode === 'search' && form.value.visitor_person_id) {
      visit.visitor_person_id = form.value.visitor_person_id
    } else {
      payload.person = {
        first_name: form.value.visitor.first_name,
        last_name: form.value.visitor.last_name,
        document_number: form.value.visitor.document_number,
        phone: form.value.visitor.phone || undefined,
        person_type: 'natural',
      }
    }

    const vehicle = form.value.vehicle
    if (vehicle.plate || vehicle.brand_model || vehicle.color) {
      visit.metadata = {
        vehicle: {
          plate: vehicle.plate || undefined,
          brand_model: vehicle.brand_model || undefined,
          color: vehicle.color || undefined,
        },
      }
    }

    return payload
  }

  return {
    currentStep,
    form,
    stepIndex,
    snapshot,
    restoreSnapshot,
    resetForm,
    goNext,
    goBack,
    validateStep,
    buildSubmitPayload,
  }
}

function mapZodErrors(error: { issues: Array<{ path: Array<string | number>; message: string }> }) {
  const errors: Record<string, string | undefined> = {}
  error.issues.forEach((issue) => {
    const key = issue.path.join('.')
    if (!errors[key]) errors[key] = issue.message
  })
  return errors
}

function prefixErrors(errors: Record<string, string | undefined>, prefix: string) {
  return Object.fromEntries(Object.entries(errors).map(([key, value]) => [`${prefix}${key}`, value]))
}

function combineDateAndTime(date: string, time: string) {
  return new Date(`${date}T${time}`).toISOString()
}
