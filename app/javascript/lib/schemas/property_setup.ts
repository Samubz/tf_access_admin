import { z } from 'zod'
import { PROPERTY_TYPE_VALUES } from '@/lib/schemas/residential_property'

export const STRUCTURE_MODES = ['none', 'manual', 'quick'] as const
export const UNITS_MODES = ['automatic', 'import', 'manual'] as const
export const IDENTIFIER_FORMATS = ['floor_sequential', 'block_sequential', 'sequential'] as const

export const propertySetupValidationKeys = {
  step1: {
    name_required: 'admin.property_setup.step1.validations.name_required',
    property_type_required: 'admin.property_setup.step1.validations.property_type_required',
    address_required: 'admin.property_setup.step1.validations.address_required',
  },
  step2: {
    mode_required: 'admin.property_setup.step2.errors.mode_required',
    manual_empty: 'admin.property_setup.step2.errors.manual_empty',
    quick_not_confirmed: 'admin.property_setup.step2.errors.quick_not_confirmed',
    level_count_min: 'admin.property_setup.step2.validations.level_count_min',
    level_prefix_required: 'admin.property_setup.step2.validations.level_prefix_required',
  },
  step3: {
    mode_required: 'admin.property_setup.step3.errors.mode_required',
    unit_type_required: 'admin.property_setup.step3.validations.unit_type_required',
    identifier_format_required: 'admin.property_setup.step3.validations.identifier_format_required',
    units_per_leaf_min: 'admin.property_setup.step3.validations.quantity_per_floor_min',
  },
} as const

const positiveInt = (message: string) =>
  z.coerce.number({ invalid_type_error: message }).int(message).min(1, message)

export const propertySetupStep1Schema = z.object({
  name: z.string().trim().min(1, propertySetupValidationKeys.step1.name_required),
  property_type: z.enum(PROPERTY_TYPE_VALUES, {
    required_error: propertySetupValidationKeys.step1.property_type_required,
    invalid_type_error: propertySetupValidationKeys.step1.property_type_required,
  }),
  address_line: z.string().trim().min(1, propertySetupValidationKeys.step1.address_required),
  city: z.string().optional(),
  region: z.string().optional(),
  country: z.string().optional(),
  timezone: z.string().optional(),
})

export const propertySetupQuickStructureSchema = z.object({
  level_1_count: positiveInt(propertySetupValidationKeys.step2.level_count_min),
  level_1_prefix: z.string().trim().min(1, propertySetupValidationKeys.step2.level_prefix_required),
  level_2_count: positiveInt(propertySetupValidationKeys.step2.level_count_min).optional(),
  level_2_prefix: z.string().trim().optional(),
  skip_top_level: z.boolean().optional(),
})

export const propertySetupUnitGenerationSchema = z.object({
  unit_type: z.string().trim().min(1, propertySetupValidationKeys.step3.unit_type_required),
  identifier_format: z.enum(IDENTIFIER_FORMATS, {
    required_error: propertySetupValidationKeys.step3.identifier_format_required,
    invalid_type_error: propertySetupValidationKeys.step3.identifier_format_required,
  }),
  units_per_leaf: positiveInt(propertySetupValidationKeys.step3.units_per_leaf_min),
})

export const propertySetupStep2Schema = z.object({
  structure_mode: z.enum(STRUCTURE_MODES, {
    required_error: propertySetupValidationKeys.step2.mode_required,
    invalid_type_error: propertySetupValidationKeys.step2.mode_required,
  }),
  quick_structure_confirmed: z.boolean().optional(),
  quick_structure: propertySetupQuickStructureSchema.optional(),
})

export const propertySetupStep3Schema = z.object({
  units_mode: z.enum(UNITS_MODES, {
    required_error: propertySetupValidationKeys.step3.mode_required,
    invalid_type_error: propertySetupValidationKeys.step3.mode_required,
  }),
  unit_generation: propertySetupUnitGenerationSchema.partial().optional(),
})

export type PropertySetupStep1Values = z.infer<typeof propertySetupStep1Schema>
export type PropertySetupStep2Values = z.infer<typeof propertySetupStep2Schema>
export type PropertySetupStep3Values = z.infer<typeof propertySetupStep3Schema>
export type PropertySetupQuickStructureValues = z.infer<typeof propertySetupQuickStructureSchema>
export type PropertySetupUnitGenerationValues = z.infer<typeof propertySetupUnitGenerationSchema>

export function mapPropertySetupZodErrors(
  error: { issues: Array<{ path: Array<string | number>; message: string }> },
): Record<string, string> {
  const errors: Record<string, string> = {}
  error.issues.forEach((issue) => {
    const key = issue.path.join('.')
    if (!errors[key]) errors[key] = issue.message
  })
  return errors
}

export function validatePropertySetupStep2(
  values: PropertySetupStep2Values,
  context: { sectionsCount: number },
): Record<string, string> {
  const result = propertySetupStep2Schema.safeParse(values)
  const errors = result.success ? {} : mapPropertySetupZodErrors(result.error)

  if (values.structure_mode === 'manual' && context.sectionsCount <= 0) {
    errors.structure = propertySetupValidationKeys.step2.manual_empty
  }

  if (values.structure_mode === 'quick') {
    const quickResult = propertySetupQuickStructureSchema.safeParse(values.quick_structure ?? {})
    if (!quickResult.success) {
      Object.assign(errors, prefixPropertySetupErrors(mapPropertySetupZodErrors(quickResult.error), 'quick_structure.'))
    }

    if (!values.quick_structure_confirmed) {
      errors.quick_structure = propertySetupValidationKeys.step2.quick_not_confirmed
    }
  }

  return errors
}

export function validatePropertySetupStep3(values: PropertySetupStep3Values): Record<string, string> {
  const result = propertySetupStep3Schema.safeParse(values)
  const errors = result.success ? {} : mapPropertySetupZodErrors(result.error)

  if (values.units_mode === 'automatic') {
    const generationResult = propertySetupUnitGenerationSchema.safeParse(values.unit_generation ?? {})
    if (!generationResult.success) {
      Object.assign(
        errors,
        prefixPropertySetupErrors(mapPropertySetupZodErrors(generationResult.error), 'unit_generation.'),
      )
    }
  }

  return errors
}

function prefixPropertySetupErrors(errors: Record<string, string>, prefix: string) {
  return Object.fromEntries(Object.entries(errors).map(([key, value]) => [`${prefix}${key}`, value]))
}
