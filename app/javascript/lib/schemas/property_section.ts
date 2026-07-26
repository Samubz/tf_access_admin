import { z } from 'zod'

/** Keep in sync with `SectionTypes::ALL` in Ruby. */
export const SECTION_TYPE_VALUES = [
  'building',
  'tower',
  'floor',
  'block',
  'stage',
  'sector',
  'parking_area',
  'storage_area',
  'other',
] as const

/** Canonical lifecycle values — keep in sync with `SectionStatuses::ALL`. */
export const SECTION_STATUS_VALUES = ['active', 'inactive', 'archived'] as const

/** Statuses selectable in ordinary create/edit forms (archived is excluded). */
export const EDITABLE_SECTION_STATUSES = ['active', 'inactive'] as const

export const propertySectionValidationKeys = {
  name_required: 'admin.property_sections.validations.name_required',
  section_type_required: 'admin.property_sections.validations.section_type_required',
  residential_property_required: 'admin.property_sections.validations.residential_property_required',
  status_required: 'admin.property_sections.validations.status_required',
} as const

const emptyToUndefined = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  return v
}, z.string().optional())

const sectionTypeSchema = z.enum(SECTION_TYPE_VALUES, {
  required_error: propertySectionValidationKeys.section_type_required,
  invalid_type_error: propertySectionValidationKeys.section_type_required,
})

const editableStatusSchema = z.enum(EDITABLE_SECTION_STATUSES, {
  required_error: propertySectionValidationKeys.status_required,
  invalid_type_error: propertySectionValidationKeys.status_required,
})

const positionSchema = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  const n = Number(v)
  return Number.isNaN(n) ? undefined : n
}, z.number().int().optional())

export const propertySectionSchema = z.object({
  name: z.string().min(1, propertySectionValidationKeys.name_required),
  code: emptyToUndefined,
  section_type: sectionTypeSchema,
  residential_property_id: z
    .string()
    .min(1, propertySectionValidationKeys.residential_property_required),
  parent_id: emptyToUndefined,
  position: positionSchema,
})

export type PropertySectionSchema = z.infer<typeof propertySectionSchema>

export const propertySectionEditSchema = propertySectionSchema.extend({
  status: editableStatusSchema,
})

export type PropertySectionEditSchema = z.infer<typeof propertySectionEditSchema>
