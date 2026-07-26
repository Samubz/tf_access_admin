import { z } from 'zod'
import {
  EDITABLE_SECTION_STATUSES,
  SECTION_TYPE_VALUES,
} from '@/lib/schemas/property_section'

export const PLACEMENT_MODES = ['root', 'child'] as const

export const propertySectionStructureValidationKeys = {
  name_required: 'admin.property_sections.validations.name_required',
  section_type_required: 'admin.property_sections.validations.section_type_required',
  parent_required: 'admin.property_sections.validations.parent_required',
  position_min: 'admin.property_sections.validations.position_min',
  status_required: 'admin.property_sections.validations.status_required',
} as const

const emptyToUndefined = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  return v
}, z.string().optional())

const sectionTypeSchema = z.enum(SECTION_TYPE_VALUES, {
  required_error: propertySectionStructureValidationKeys.section_type_required,
  invalid_type_error: propertySectionStructureValidationKeys.section_type_required,
})

const editableStatusSchema = z.enum(EDITABLE_SECTION_STATUSES, {
  required_error: propertySectionStructureValidationKeys.status_required,
  invalid_type_error: propertySectionStructureValidationKeys.status_required,
})

const positionSchema = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  const n = Number(v)
  return Number.isNaN(n) ? undefined : n
}, z.number().int().min(1, propertySectionStructureValidationKeys.position_min).optional())

const sharedFields = {
  name: z.string().trim().min(1, propertySectionStructureValidationKeys.name_required),
  code: emptyToUndefined,
  section_type: sectionTypeSchema,
  parent_id: emptyToUndefined,
  position: positionSchema,
}

/** Create flow — no lifecycle status (backend defaults to active). */
export const propertySectionStructureCreateSchema = z
  .object({
    placement: z.enum(PLACEMENT_MODES),
    ...sharedFields,
  })
  .superRefine((data, ctx) => {
    if (data.placement === 'child' && !data.parent_id) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: propertySectionStructureValidationKeys.parent_required,
        path: ['parent_id'],
      })
    }
  })

/** Edit flow — descriptive fields plus active/inactive status only. */
export const propertySectionStructureEditSchema = z.object({
  placement: z.enum(PLACEMENT_MODES),
  status: editableStatusSchema,
  ...sharedFields,
})

export type PropertySectionStructureCreateSchema = z.infer<
  typeof propertySectionStructureCreateSchema
>
export type PropertySectionStructureEditSchema = z.infer<
  typeof propertySectionStructureEditSchema
>
export type PropertySectionStructureSchema =
  | PropertySectionStructureCreateSchema
  | PropertySectionStructureEditSchema

export const BATCH_MODES = ['individual', 'multiple'] as const
export const SUFFIX_TYPES = ['letter', 'number'] as const

export const propertySectionBatchValidationKeys = {
  name_required: 'admin.property_sections.validations.name_required',
  section_type_required: 'admin.property_sections.validations.section_type_required',
  prefix_required: 'admin.property_setup.step2.manual.validations.prefix_required',
  count_min: 'admin.property_setup.step2.manual.validations.count_min',
} as const

const countSchema = z.preprocess((v) => {
  if (v === '' || v === null || v === undefined) return undefined
  const n = Number(v)
  return Number.isNaN(n) ? undefined : n
}, z.number().int().min(1, propertySectionBatchValidationKeys.count_min).optional())

/** Manual builder batch create (individual or multiple) under one context. */
export const propertySectionBatchCreateSchema = z
  .object({
    mode: z.enum(BATCH_MODES),
    placement: z.enum(PLACEMENT_MODES),
    section_type: sectionTypeSchema,
    parent_id: emptyToUndefined,
    // individual
    name: z.string().trim().optional(),
    code: emptyToUndefined,
    // multiple
    prefix: z.string().trim().optional(),
    suffix_type: z.enum(SUFFIX_TYPES).optional(),
    count: countSchema,
  })
  .superRefine((data, ctx) => {
    if (data.placement === 'child' && !data.parent_id) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: propertySectionStructureValidationKeys.parent_required,
        path: ['parent_id'],
      })
    }

    if (data.mode === 'individual' && !data.name) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: propertySectionBatchValidationKeys.name_required,
        path: ['name'],
      })
    }

    if (data.mode === 'multiple') {
      if (!data.prefix) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: propertySectionBatchValidationKeys.prefix_required,
          path: ['prefix'],
        })
      }
      if (!data.count) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: propertySectionBatchValidationKeys.count_min,
          path: ['count'],
        })
      }
    }
  })

export type PropertySectionBatchCreateSchema = z.infer<typeof propertySectionBatchCreateSchema>

export const propertySectionMoveSchema = z.object({
  parent_id: emptyToUndefined,
  position: positionSchema,
})

export type PropertySectionMoveSchema = z.infer<typeof propertySectionMoveSchema>
