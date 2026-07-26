import { z } from 'zod'

export const VISIT_CREATE_STEPS = [
  'general',
  'visitor',
  'schedule',
  'additional',
  'confirm',
] as const

export type VisitCreateStep = (typeof VISIT_CREATE_STEPS)[number]

export type VisitCreateVisitorMode = 'search' | 'create'

export type VisitCreatePersonForm = {
  document_number: string
  first_name: string
  last_name: string
  phone: string
}

export type VisitCreateVehicleForm = {
  plate: string
  brand_model: string
  color: string
}

export type VisitCreateForm = {
  residential_property_id: string
  // Cached labels for the selected property/unit so the searchable selects
  // and summary panel can render them without a full options list
  // (improve-admin-visit-form-inputs). Not sent in the submit payload.
  residential_property_name: string
  unit_id: string
  unit_label: string
  visitor_mode: VisitCreateVisitorMode
  visitor_person_id: string
  visitor: VisitCreatePersonForm
  visit_date: string
  start_time: string
  end_time: string
  visit_type: string
  vehicle: VisitCreateVehicleForm
  notes: string
}

export function createEmptyVisitCreateForm(defaultVisitType = 'guest'): VisitCreateForm {
  return {
    residential_property_id: '',
    residential_property_name: '',
    unit_id: '',
    unit_label: '',
    visitor_mode: 'search',
    visitor_person_id: '',
    visitor: {
      document_number: '',
      first_name: '',
      last_name: '',
      phone: '',
    },
    visit_date: '',
    start_time: '',
    end_time: '',
    visit_type: defaultVisitType,
    vehicle: {
      plate: '',
      brand_model: '',
      color: '',
    },
    notes: '',
  }
}

export const visitCreatePersonSchema = z.object({
  document_number: z.string().trim().min(1, 'admin.visits.new.validations.document_required'),
  first_name: z.string().trim().min(1, 'admin.visits.new.validations.first_name_required'),
  last_name: z.string().trim().min(1, 'admin.visits.new.validations.last_name_required'),
  phone: z.string().optional(),
})

export const visitCreateGeneralSchema = z.object({
  residential_property_id: z.string().trim().min(1, 'admin.visits.new.validations.property_required'),
  unit_id: z.string().trim().min(1, 'admin.visits.new.validations.unit_required'),
})

export const visitCreateScheduleSchema = z.object({
  visit_date: z.string().trim().min(1, 'admin.visits.new.validations.date_required'),
  start_time: z.string().trim().min(1, 'admin.visits.new.validations.start_time_required'),
  end_time: z.string().optional(),
})

export const visitCreateAdditionalSchema = z.object({
  visit_type: z.string().trim().min(1, 'admin.visits.new.validations.visit_type_required'),
})

export type VisitInitialStatusPreview = {
  initial_status: string
  initial_status_label: string
  message: string
}

export type VisitTypeOption = {
  value: string
  label: string
}

export type VisitCreateSubmitPayload = {
  visit: {
    unit_id: string
    scheduled_at: string
    valid_from: string
    valid_until?: string
    visit_type: string
    notes?: string
    visitor_person_id?: string
    metadata?: {
      vehicle?: {
        plate?: string
        brand_model?: string
        color?: string
      }
    }
  }
  person?: {
    first_name: string
    last_name: string
    document_number: string
    phone?: string
    person_type: string
  }
  return_to?: string
  context?: {
    unit_id: string
    return_to: string
  }
}
