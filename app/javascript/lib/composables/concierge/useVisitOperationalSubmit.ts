import { ref, watch } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import {
  admin_visit_check_ins_path,
  admin_visit_check_outs_path,
  check_in_concierge_visit_path,
  check_out_concierge_visit_path,
} from '@/routes'
import type { ConciergeVisitListItem } from '@/types/visit'

type ReturnTarget = 'list' | 'detail'
type VisitNamespace = 'admin' | 'concierge'

type CheckInPayload = {
  access_point: string
  access_type: string
  vehicle_plate?: string
  notes?: string
}

type CheckOutPayload = {
  access_point: string
  incident_type?: string
  notes?: string
}

type Options = {
  returnTo: ReturnTarget
  namespace?: VisitNamespace
}

export function useVisitOperationalSubmit({ returnTo, namespace = 'concierge' }: Options) {
  const submitting = ref(false)
  const errors = ref<string[]>([])
  const page = usePage()

  watch(
    () => page.props.errors as Record<string, string | string[]> | undefined,
    (errs) => {
      if (!errs?.base) return
      errors.value = Array.isArray(errs.base) ? errs.base : [errs.base]
    },
    { deep: true },
  )

  function submitCheckIn(visit: ConciergeVisitListItem, payload: CheckInPayload, onSuccess?: () => void) {
    submitting.value = true
    errors.value = []

    const url =
      namespace === 'admin'
        ? admin_visit_check_ins_path(visit.id)
        : check_in_concierge_visit_path(visit.id)

    router.post(
      url,
      {
        return_to: returnTo === 'list' ? 'list' : undefined,
        check_in: payload,
      },
      {
        onSuccess: () => onSuccess?.(),
        onError: (errs) => {
          errors.value = normalizeErrors(errs)
        },
        onFinish: () => {
          submitting.value = false
        },
      },
    )
  }

  function submitCheckOut(visit: ConciergeVisitListItem, payload: CheckOutPayload, onSuccess?: () => void) {
    submitting.value = true
    errors.value = []

    const url =
      namespace === 'admin'
        ? admin_visit_check_outs_path(visit.id)
        : check_out_concierge_visit_path(visit.id)

    router.post(
      url,
      {
        return_to: returnTo === 'list' ? 'list' : undefined,
        check_out: payload,
      },
      {
        onSuccess: () => onSuccess?.(),
        onError: (errs) => {
          errors.value = normalizeErrors(errs)
        },
        onFinish: () => {
          submitting.value = false
        },
      },
    )
  }

  return {
    submitting,
    errors,
    submitCheckIn,
    submitCheckOut,
  }
}

function normalizeErrors(errs: Record<string, string | string[]>) {
  if (errs.base) {
    return Array.isArray(errs.base) ? errs.base : [errs.base]
  }

  return Object.values(errs).flatMap((value) => (Array.isArray(value) ? value : [value]))
}
