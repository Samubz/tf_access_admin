export type BulkImportColumnMapping = {
  source: string | null
  target: string
  required: boolean
  matched: boolean
}

export type BulkImportFileInspection = {
  sheets: string[]
  selected_sheet: string | null
  headers: string[]
  row_count: number
  error: string | null
}

export type BulkImportOptions = {
  import_mode: string
  property_section_id?: string | null
  owner_import_mode?: string
  /** @deprecated Use owner_import_mode */
  validate_owners?: boolean
  /** @deprecated Use owner_import_mode */
  create_owners?: boolean
}

export type BulkImportMetadata = {
  file_inspection: BulkImportFileInspection
  column_mappings: BulkImportColumnMapping[]
  options: BulkImportOptions
}

export type BulkImportValidationIssue = {
  field: string
  code: string
  message: string
}

export type BulkImportRowNormalizedPayload = {
  section_path?: string | null
  section_name?: string | null
  property_section_id?: string | null
  unit_identifier?: string | null
  unit_type?: string | null
  display_name?: string | null
  area_m2?: string | null
  status?: string | null
  owner_email?: string | null
  owner_document?: string | null
  owner_first_name?: string | null
  owner_last_name?: string | null
  ownership_percentage?: number | string | null
  // Bulk user/person import fields (add-bulk-user-import)
  first_name?: string | null
  last_name?: string | null
  document_number?: string | null
  phone?: string | null
  email?: string | null
  birthdate?: string | null
}

export type BulkImportOnboardingClassification =
  | 'ready_to_create_person'
  | 'requires_invitation'
  | 'requires_incorporation'
  | 'review'
  | 'conflict'
  | 'duplicate'
  | 'invalid'

export type BulkImportRowRecord = {
  id: string
  row_number: number
  validation_status: 'pending' | 'valid' | 'warning' | 'error' | 'duplicate'
  import_status: 'pending' | 'imported' | 'skipped' | 'failed'
  onboarding_classification: BulkImportOnboardingClassification | null
  target_record_type: 'Person' | 'OnboardingRequest' | null
  validation_errors: BulkImportValidationIssue[]
  validation_warnings: BulkImportValidationIssue[]
  normalized_payload: BulkImportRowNormalizedPayload
  group_key: string | null
}

export type BulkImportPreviewSummary = {
  total_rows: number
  valid_rows: number
  warning_rows: number
  error_rows: number
  duplicate_rows: number
  skipped_rows: number
  pending_invitation_rows?: number
  pending_incorporation_rows?: number
}

export type BulkImportTriggerInvitationStatus = 'triggered' | 'conflicted' | 'skipped' | 'failed'

export type BulkImportTriggerInvitationsResult = {
  counts: {
    triggered: number
    conflicted: number
    skipped: number
    failed: number
  }
  results: Array<{
    row_id: string
    status: BulkImportTriggerInvitationStatus
    classification: BulkImportOnboardingClassification | null
  }>
}

export type BulkImportPreviewPagination = {
  current_page: number
  per_page: number
  total_pages: number
  total_count: number
}

export type BulkImportRowsResponse = {
  rows: BulkImportRowRecord[]
  pagination: BulkImportPreviewPagination
  summary: BulkImportPreviewSummary
}

export type BulkImportRecord = {
  id: string
  status: string
  import_type: string
  original_filename: string | null
  content_type: string | null
  file_size: number | null
  metadata: BulkImportMetadata
  residential_property_id: string | null
  property_section_id: string | null
  created_at: string
  total_rows: number
  valid_rows: number
  warning_rows: number
  error_rows: number
  skipped_rows: number
}

export type BulkImportImportMode =
  | 'create_skip_duplicates'
  | 'create_only'
  | 'update_only'

export type BulkImportOwnerImportMode =
  | 'ignore'
  | 'link_existing'
  | 'create_missing'

export type BulkImportConfigureForm = {
  selected_sheet: string
  import_mode: BulkImportImportMode
  property_section_id: string
  owner_import_mode: BulkImportOwnerImportMode
}

export type BulkImportImportSummary = {
  totalRows: number
  validRows: number
  warningRows: number
  errorRows: number
  duplicateRows: number
  newUnits: number
}

export type BulkImportImportProgress = {
  total: number
  processed: number
  created: number
  skipped: number
  failed: number
  percentage: number
}

export type BulkImportImportLogStatus = 'success' | 'warning' | 'error'

export type BulkImportImportLog = {
  rowNumber: number
  status: BulkImportImportLogStatus
  message: string
  createdAt?: string
}

export type BulkImportImportPhase = 'ready' | 'processing' | 'completed' | 'failed'

export type BulkImportStatusResponse = {
  status: string
  progress: BulkImportImportProgress
  logs: Array<{
    row_number: number
    status: BulkImportImportLogStatus
    message: string
    created_at?: string
  }>
  summary: BulkImportPreviewSummary & {
    imported_rows: number
    failed_rows: number
  }
}
