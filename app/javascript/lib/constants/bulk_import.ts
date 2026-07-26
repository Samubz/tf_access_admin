/** Mirrors BulkImportServices::UnitsColumnMapper::TARGET_FIELDS required flags */
export const BULK_IMPORT_REQUIRED_TARGETS = ['unit_identifier', 'unit_type'] as const

/** Mirrors BulkImportServices::PeopleColumnMapper::TARGET_FIELDS required flags */
export const BULK_PEOPLE_IMPORT_REQUIRED_TARGETS = [
  'first_name',
  'last_name',
  'document_number',
  'phone',
  'email',
  'birthdate',
] as const

/** Mirrors BulkImportServices::PeopleImportMode::IMPORT_MODES */
export const BULK_PEOPLE_IMPORT_MODES = ['create_skip_duplicates', 'create_only'] as const

export const BULK_IMPORT_IMPORT_MODES = [
  'create_skip_duplicates',
  'create_only',
  'update_only',
] as const

export const BULK_IMPORT_OWNER_IMPORT_MODES = [
  'ignore',
  'link_existing',
  'create_missing',
] as const

export const BULK_IMPORT_VALIDATION_STATUSES = [
  'pending',
  'valid',
  'warning',
  'error',
  'duplicate',
] as const

export type BulkImportValidationStatus = (typeof BULK_IMPORT_VALIDATION_STATUSES)[number]

export const BULK_IMPORT_PREVIEW_FILTERS = ['all', 'valid', 'warnings', 'errors'] as const

export type BulkImportPreviewFilter = (typeof BULK_IMPORT_PREVIEW_FILTERS)[number]

export const BULK_IMPORT_PREVIEW_PER_PAGE = 10

export const BULK_IMPORT_PREVIEW_PER_PAGE_OPTIONS = [10, 25, 50] as const

/** Import session can no longer be edited in earlier wizard steps */
export const BULK_IMPORT_LOCKED_STATUSES = [
  'confirmed',
  'processing',
  'completed',
  'completed_with_errors',
  'failed',
] as const

export function isBulkImportLocked(status: string | undefined | null): boolean {
  if (!status) return false
  return (BULK_IMPORT_LOCKED_STATUSES as readonly string[]).includes(status)
}

export function canRevalidateBulkImport(status: string | undefined | null): boolean {
  if (!status) return false
  return ['uploaded', 'validated', 'validation_failed'].includes(status)
}
