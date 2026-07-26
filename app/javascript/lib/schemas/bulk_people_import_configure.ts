import { z } from 'zod'
import {
  BULK_PEOPLE_IMPORT_MODES,
  BULK_PEOPLE_IMPORT_REQUIRED_TARGETS,
} from '@/lib/constants/bulk_import'
import type { BulkImportColumnMapping } from '@/types/bulk_import'

export const bulkPeopleImportConfigureValidationKeys = {
  selected_sheet_required: 'admin.people.bulk_import.configure.validations.selected_sheet_required',
  import_mode_required: 'admin.people.bulk_import.configure.validations.import_mode_required',
  required_columns_missing: 'admin.people.bulk_import.configure.validations.required_columns_missing',
} as const

const importModeSchema = z.enum(BULK_PEOPLE_IMPORT_MODES, {
  required_error: bulkPeopleImportConfigureValidationKeys.import_mode_required,
  invalid_type_error: bulkPeopleImportConfigureValidationKeys.import_mode_required,
})

export const bulkPeopleImportConfigureFieldsSchema = z.object({
  selected_sheet: z.string().trim().min(1, bulkPeopleImportConfigureValidationKeys.selected_sheet_required),
  import_mode: importModeSchema,
})

export function createBulkPeopleImportConfigureSchema(columnMappings: BulkImportColumnMapping[]) {
  return bulkPeopleImportConfigureFieldsSchema.superRefine((_data, ctx) => {
    const missingRequired = columnMappings.filter(
      (mapping) =>
        BULK_PEOPLE_IMPORT_REQUIRED_TARGETS.includes(
          mapping.target as (typeof BULK_PEOPLE_IMPORT_REQUIRED_TARGETS)[number],
        ) && !mapping.matched,
    )

    if (missingRequired.length === 0) return

    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: bulkPeopleImportConfigureValidationKeys.required_columns_missing,
      path: ['column_mappings'],
    })
  })
}

export type BulkPeopleImportConfigureFieldsSchema = z.infer<typeof bulkPeopleImportConfigureFieldsSchema>
