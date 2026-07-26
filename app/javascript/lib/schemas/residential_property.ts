import { z } from 'zod'

/** Keep in sync with `PropertyTypes::ALL` in Ruby. */
export const PROPERTY_TYPE_VALUES = [
  'building',
  'condominium',
  'horizontal_community',
  'residential_complex',
  'mixed_use',
  'tower',
  'sector',
  'other',
] as const

/** Canonical lifecycle values — keep in sync with `PropertyStatuses::ALL`. */
export const RESIDENTIAL_PROPERTY_STATUS_VALUES = ['active', 'inactive', 'archived'] as const

/** Statuses selectable in ordinary create/edit forms (archived is excluded). */
export const EDITABLE_RESIDENTIAL_PROPERTY_STATUSES = ['active', 'inactive'] as const

/** @deprecated Use EDITABLE_RESIDENTIAL_PROPERTY_STATUSES for form selectors. */
export const RESIDENTIAL_PROPERTY_STATUSES = EDITABLE_RESIDENTIAL_PROPERTY_STATUSES

export const residentialPropertyValidationKeys = {
  name_required: 'admin.residential_properties.validations.name_required',
  property_type_required: 'admin.residential_properties.validations.property_type_required',
  status_required: 'admin.residential_properties.validations.status_required',
  country_required: 'admin.residential_properties.validations.country_required',
  timezone_required: 'admin.residential_properties.validations.timezone_required',
} as const

const emptyToUndefined = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  return v
}, z.string().optional())

const propertyTypeSchema = z.enum(PROPERTY_TYPE_VALUES, {
  required_error: residentialPropertyValidationKeys.property_type_required,
  invalid_type_error: residentialPropertyValidationKeys.property_type_required,
})

const editableStatusSchema = z.enum(EDITABLE_RESIDENTIAL_PROPERTY_STATUSES, {
  required_error: residentialPropertyValidationKeys.status_required,
  invalid_type_error: residentialPropertyValidationKeys.status_required,
})

const baseResidentialPropertySchema = z.object({
  name: z.string().min(1, residentialPropertyValidationKeys.name_required),
  property_type: propertyTypeSchema,
  address_line: emptyToUndefined,
  city: emptyToUndefined,
  region: emptyToUndefined,
  country: z.string().min(1, residentialPropertyValidationKeys.country_required),
  timezone: z.string().min(1, residentialPropertyValidationKeys.timezone_required),
})

/** Nombre distinto de `country` para evitar que el autofill del navegador vacíe el input (`name="country"`). */
export const residentialPropertyCreateSchema = baseResidentialPropertySchema

export const residentialPropertyEditSchema = baseResidentialPropertySchema.extend({
  status: editableStatusSchema,
})

/** @deprecated Use residentialPropertyCreateSchema or residentialPropertyEditSchema. */
export const residentialPropertySchema = residentialPropertyEditSchema

export type ResidentialPropertyCreateSchema = z.infer<typeof residentialPropertyCreateSchema>
export type ResidentialPropertyEditSchema = z.infer<typeof residentialPropertyEditSchema>
export type ResidentialPropertySchema = ResidentialPropertyEditSchema
