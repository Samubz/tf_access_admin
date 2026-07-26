import { computed, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'

import type {
  BulkImportRecord,
  BulkImportRowsResponse,
} from '@/types/bulk_import'
import { BULK_PEOPLE_IMPORT_MODES, isBulkImportLocked } from '@/lib/constants/bulk_import'
import {
  admin_people_bulk_import_path,
  admin_people_bulk_imports_path,
} from '@/routes'

type BulkPeopleImportImportMode = (typeof BULK_PEOPLE_IMPORT_MODES)[number]

function validateBulkImportPath(bulkImportId: string) {
  return `${admin_people_bulk_import_path(bulkImportId)}/validate`
}

export const BULK_PEOPLE_IMPORT_STEPS = ['method', 'configure', 'preview', 'import'] as const
export type BulkPeopleImportStep = (typeof BULK_PEOPLE_IMPORT_STEPS)[number]

export const BULK_PEOPLE_IMPORT_ACCEPT =
  '.xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv'

type BulkImportResponse = {
  bulk_import: BulkImportRecord
}

type BulkImportValidateResponse = BulkImportResponse & BulkImportRowsResponse

type BulkImportErrorResponse = {
  errors?: Record<string, string[]>
}

export type BulkPeopleImportConfigureForm = {
  selected_sheet: string
  import_mode: BulkPeopleImportImportMode
}

function buildConfigureForm(record: BulkImportRecord): BulkPeopleImportConfigureForm {
  const inspection = record.metadata.file_inspection
  const options = record.metadata.options

  return {
    selected_sheet: inspection.selected_sheet ?? inspection.sheets[0] ?? '',
    import_mode: (options.import_mode ?? 'create_skip_duplicates') as BulkPeopleImportImportMode,
  }
}

function errorMessage(data: BulkImportErrorResponse, fallback: string): string {
  return data.errors?.base?.[0] ?? data.errors?.file?.[0] ?? data.errors?.selected_sheet?.[0] ?? fallback
}

export function useBulkPeopleImportWizard() {
  const { t } = useI18n()
  const { railsFetchJson, objectToRailsFormData } = useRailsFetch()

  const state = reactive({
    currentStep: 'method' as BulkPeopleImportStep,
    selectedFile: null as File | null,
    fileError: null as string | null,
    bulkImport: null as BulkImportRecord | null,
    configureForm: null as BulkPeopleImportConfigureForm | null,
    initialPreview: null as BulkImportRowsResponse | null,
    isSubmitting: false,
    isRefreshingSheet: false,
    isValidating: false,
  })

  const isConfigureStepValid = ref(false)
  const isPreviewStepConfirmable = ref(false)

  const stepIndex = computed(() => BULK_PEOPLE_IMPORT_STEPS.indexOf(state.currentStep))

  const canGoNext = computed(() => {
    if (state.isSubmitting || state.isRefreshingSheet) return false

    if (state.currentStep === 'method') {
      return state.selectedFile !== null && state.fileError === null
    }

    if (state.currentStep === 'configure') {
      return (
        state.bulkImport !== null &&
        state.configureForm !== null &&
        isConfigureStepValid.value &&
        !isBulkImportLocked(state.bulkImport.status)
      )
    }

    if (state.currentStep === 'preview') {
      return isPreviewStepConfirmable.value && !state.isValidating
    }

    return false
  })

  const canGoBack = computed(
    () =>
      (state.currentStep === 'configure' ||
        state.currentStep === 'preview' ||
        state.currentStep === 'import') &&
      !state.isSubmitting &&
      !state.isValidating,
  )

  function reset() {
    state.currentStep = 'method'
    state.selectedFile = null
    state.fileError = null
    state.bulkImport = null
    state.configureForm = null
    state.initialPreview = null
    state.isSubmitting = false
    state.isRefreshingSheet = false
    state.isValidating = false
    isConfigureStepValid.value = false
    isPreviewStepConfirmable.value = false
  }

  function applyBulkImportResponse(record: BulkImportRecord) {
    state.bulkImport = record
    state.configureForm = buildConfigureForm(record)
  }

  async function uploadBulkImport() {
    if (!state.selectedFile || state.fileError) return

    state.isSubmitting = true

    try {
      const bulkImportId = state.bulkImport?.id
      const formData = objectToRailsFormData('bulk_import', { file: state.selectedFile })
      const url = bulkImportId
        ? admin_people_bulk_import_path(bulkImportId)
        : admin_people_bulk_imports_path()
      const method = bulkImportId ? 'PATCH' : 'POST'

      const { res, data } = await railsFetchJson<BulkImportResponse & BulkImportErrorResponse>(
        method,
        url,
        formData,
      )

      if (!res.ok) {
        toast.error(errorMessage(data, t('admin.people.bulk_import.errors.upload_failed')))
        return
      }

      applyBulkImportResponse(data.bulk_import)
      state.currentStep = 'configure'
      toast.success(
        bulkImportId
          ? t('admin.people.bulk_import.upload.replaced_success')
          : t('admin.people.bulk_import.upload.uploaded_success'),
      )
    } catch {
      toast.error(t('admin.people.bulk_import.errors.upload_failed'))
    } finally {
      state.isSubmitting = false
    }
  }

  async function refreshSheetInspection(selectedSheet: string) {
    const bulkImportId = state.bulkImport?.id
    if (!bulkImportId || !selectedSheet) return

    state.isRefreshingSheet = true

    try {
      const formData = objectToRailsFormData('bulk_import', { selected_sheet: selectedSheet })
      const { res, data } = await railsFetchJson<BulkImportResponse & BulkImportErrorResponse>(
        'PATCH',
        admin_people_bulk_import_path(bulkImportId),
        formData,
      )

      if (!res.ok) {
        toast.error(errorMessage(data, t('admin.people.bulk_import.errors.sheet_refresh_failed')))
        return
      }

      applyBulkImportResponse(data.bulk_import)
    } catch {
      toast.error(t('admin.people.bulk_import.errors.sheet_refresh_failed'))
    } finally {
      state.isRefreshingSheet = false
    }
  }

  async function saveConfigureOptions() {
    const bulkImportId = state.bulkImport?.id
    const form = state.configureForm
    if (!bulkImportId || !form) return false

    const formData = objectToRailsFormData('bulk_import', {
      selected_sheet: form.selected_sheet,
      import_mode: form.import_mode,
    })

    const { res, data } = await railsFetchJson<BulkImportResponse & BulkImportErrorResponse>(
      'PATCH',
      admin_people_bulk_import_path(bulkImportId),
      formData,
    )

    if (!res.ok) {
      toast.error(errorMessage(data, t('admin.people.bulk_import.errors.configure_save_failed')))
      return false
    }

    applyBulkImportResponse(data.bulk_import)
    return true
  }

  async function validateBulkImport() {
    const bulkImportId = state.bulkImport?.id
    if (!bulkImportId) return false

    state.isValidating = true

    try {
      const { res, data } = await railsFetchJson<BulkImportValidateResponse & BulkImportErrorResponse>(
        'POST',
        validateBulkImportPath(bulkImportId),
      )

      if (!res.ok) {
        toast.error(errorMessage(data, t('admin.people.bulk_import.errors.validation_failed')))
        return false
      }

      applyBulkImportResponse(data.bulk_import)
      state.initialPreview = {
        rows: data.rows ?? [],
        pagination: data.pagination,
        summary: data.summary,
      }
      return true
    } catch {
      toast.error(t('admin.people.bulk_import.errors.validation_failed'))
      return false
    } finally {
      state.isValidating = false
    }
  }

  async function proceedFromConfigure() {
    if (isBulkImportLocked(state.bulkImport?.status)) {
      toast.error(t('admin.people.bulk_import.errors.wizard_locked'))
      return
    }

    state.isSubmitting = true

    try {
      const saved = await saveConfigureOptions()
      if (!saved) return

      if (state.bulkImport?.status === 'validated' && state.initialPreview !== null) {
        state.currentStep = 'preview'
        return
      }

      const validated = await validateBulkImport()
      if (!validated) return

      state.currentStep = 'preview'
    } finally {
      state.isSubmitting = false
    }
  }

  function goToNextStep() {
    if (state.currentStep === 'method') {
      void uploadBulkImport()
      return
    }

    if (state.currentStep === 'configure') {
      void proceedFromConfigure()
      return
    }

    const nextIndex = stepIndex.value + 1
    if (nextIndex < BULK_PEOPLE_IMPORT_STEPS.length) {
      state.currentStep = BULK_PEOPLE_IMPORT_STEPS[nextIndex]
    }
  }

  function goToPreviousStep() {
    if (state.currentStep === 'import') {
      state.currentStep = 'preview'
      return
    }

    if (state.currentStep === 'preview') {
      if (isBulkImportLocked(state.bulkImport?.status)) {
        toast.error(t('admin.people.bulk_import.errors.wizard_locked'))
        return
      }
      state.initialPreview = null
      state.currentStep = 'configure'
      return
    }

    if (state.currentStep === 'configure') {
      state.currentStep = 'method'
    }
  }

  function prepareFileReplacement() {
    state.currentStep = 'method'
    state.selectedFile = null
    state.fileError = null
    state.configureForm = null
    state.initialPreview = null
    isConfigureStepValid.value = false
  }

  function setConfigureStepValid(valid: boolean) {
    isConfigureStepValid.value = valid
  }

  function setPreviewStepConfirmable(confirmable: boolean) {
    isPreviewStepConfirmable.value = confirmable
  }

  return {
    state,
    stepIndex,
    canGoNext,
    canGoBack,
    reset,
    goToNextStep,
    goToPreviousStep,
    prepareFileReplacement,
    refreshSheetInspection,
    setConfigureStepValid,
    setPreviewStepConfirmable,
    applyBulkImportResponse,
  }
}
