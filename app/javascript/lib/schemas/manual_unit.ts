import { z } from 'zod'

export const MANUAL_UNIT_BATCH_MODES = ['individual', 'multiple'] as const
export const MANUAL_UNIT_SUFFIX_TYPES = ['letter', 'number'] as const

export const manualUnitValidationKeys = {
  unit_type_required: 'admin.property_setup.step3.manual.validations.unit_type_required',
  identifier_required: 'admin.property_setup.step3.manual.validations.identifier_required',
  prefix_required: 'admin.property_setup.step3.manual.validations.prefix_required',
  count_min: 'admin.property_setup.step3.manual.validations.count_min',
  area_m2_positive: 'admin.property_setup.step3.manual.validations.area_m2_positive',
} as const

const emptyToUndefined = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  return v
}, z.string().optional())

const areaM2Schema = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  const n = Number(v)
  return Number.isNaN(n) ? undefined : n
}, z.number().positive(manualUnitValidationKeys.area_m2_positive).optional())

const countSchema = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  const n = Number(v)
  return Number.isNaN(n) ? undefined : n
}, z.number().int().min(1, manualUnitValidationKeys.count_min).optional())

/** Manual add-unit dialog (individual or multiple) under one eligible section. */
export const manualUnitCreateSchema = z
  .object({
    mode: z.enum(MANUAL_UNIT_BATCH_MODES),
    unit_type: z.string().trim().min(1, manualUnitValidationKeys.unit_type_required),
    area_m2: areaM2Schema,
    // individual
    identifier: z.string().trim().optional(),
    display_name: emptyToUndefined,
    // multiple
    prefix: z.string().trim().optional(),
    suffix_type: z.enum(MANUAL_UNIT_SUFFIX_TYPES).optional(),
    count: countSchema,
  })
  .superRefine((data, ctx) => {
    if (data.mode === 'individual' && !data.identifier) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: manualUnitValidationKeys.identifier_required,
        path: ['identifier'],
      })
    }

    if (data.mode === 'multiple') {
      if (!data.prefix) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: manualUnitValidationKeys.prefix_required,
          path: ['prefix'],
        })
      }
      if (!data.count) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: manualUnitValidationKeys.count_min,
          path: ['count'],
        })
      }
    }
  })

export type ManualUnitCreateSchema = z.infer<typeof manualUnitCreateSchema>

/** Unit edit dialog — descriptive fields only. */
export const manualUnitEditSchema = z.object({
  identifier: z.string().trim().min(1, manualUnitValidationKeys.identifier_required),
  display_name: emptyToUndefined,
  unit_type: z.string().trim().min(1, manualUnitValidationKeys.unit_type_required),
  area_m2: areaM2Schema,
})

export type ManualUnitEditSchema = z.infer<typeof manualUnitEditSchema>

export function mapManualUnitZodErrors(
  error: { issues: Array<{ path: Array<string | number>; message: string }> },
): Record<string, string> {
  const errors: Record<string, string> = {}
  error.issues.forEach((issue) => {
    const key = issue.path.join('.')
    if (!errors[key]) errors[key] = issue.message
  })
  return errors
}
