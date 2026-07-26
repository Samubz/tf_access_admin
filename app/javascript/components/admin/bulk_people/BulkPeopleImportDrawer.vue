<template>
  <Drawer v-model:open="open" direction="right">
    <DrawerContent
      :class="[
        'flex h-full max-h-screen flex-col data-[vaul-drawer-direction=right]:w-full',
        currentStep === 'preview' || currentStep === 'import'
          ? 'data-[vaul-drawer-direction=right]:sm:max-w-6xl'
          : 'data-[vaul-drawer-direction=right]:sm:max-w-4xl',
      ]"
    >
      <DrawerHeader class="shrink-0 border-b pb-4">
        <div class="flex items-start justify-between gap-4">
          <DrawerTitle class="text-lg font-semibold">
            {{ t('admin.people.bulk_import.title') }}
          </DrawerTitle>
          <DrawerClose as-child>
            <Button type="button" variant="ghost" size="icon" :aria-label="t('admin.people.bulk_import.actions.close')">
              <X class="size-4" />
            </Button>
          </DrawerClose>
        </div>
        <BulkPeopleImportStepper :step-index="stepIndex" />
      </DrawerHeader>

      <div class="flex-1 space-y-6 overflow-y-auto px-4 py-5">
        <BulkPeopleImportMethodStep
          v-if="currentStep === 'method'"
          v-model:selected-file="selectedFile"
          v-model:file-error="fileError"
          :excel-accept="BULK_PEOPLE_IMPORT_ACCEPT"
          @download-template="onDownloadTemplate"
        />

        <BulkPeopleImportConfigureStep
          v-else-if="currentStep === 'configure' && bulkImport && configureForm"
          v-model:configure-form="configureForm"
          :bulk-import="bulkImport"
          :is-refreshing-sheet="isRefreshingSheet"
          @change-file="onChangeFile"
          @refresh-sheet="onRefreshSheet"
          @valid-change="setConfigureStepValid"
        />

        <BulkPeopleImportPreviewStep
          v-else-if="currentStep === 'preview' && bulkImport && configureForm"
          :bulk-import="bulkImport"
          :initial-preview="initialPreview"
          :is-validating="isValidating"
          @can-continue-change="setPreviewStepConfirmable"
        />

        <BulkPeopleImportImportStep
          v-else-if="currentStep === 'import' && bulkImport && configureForm && importSummary"
          v-model:import-valid-rows-only="importValidRowsOnly"
          :bulk-import-id="bulkImport.id"
          :summary="importSummary"
          :phase="importPhase"
          :progress="importProgress"
          :logs="importLogs"
          :has-pending-issues="importHasPendingIssues"
          :format-log-time="formatImportLogTime"
        />

        <div
          v-else-if="currentStep !== 'import'"
          class="flex min-h-48 items-center justify-center rounded-lg border border-dashed bg-muted/20 px-6 text-center text-sm text-muted-foreground"
        >
          {{ t('admin.people.bulk_import.placeholder_step') }}
        </div>
      </div>

      <DrawerFooter class="shrink-0 gap-2 border-t sm:flex-row sm:justify-between">
        <div class="flex flex-wrap gap-2">
          <Button
            v-if="showBackButton"
            type="button"
            variant="outline"
            :disabled="isBackDisabled"
            @click="onBack"
          >
            {{ t('admin.people.bulk_import.actions.back') }}
          </Button>
          <Button
            v-if="currentStep === 'import' && (importIsCompleted || importIsFailed)"
            type="button"
            variant="outline"
            @click="onDownloadImportReport"
          >
            <Download class="size-4" />
            {{ t('admin.people.bulk_import.import.actions.download_report') }}
          </Button>
        </div>

        <div class="flex flex-wrap justify-end gap-2">
          <DrawerClose v-if="showCancelButton" as-child>
            <Button type="button" variant="outline" :disabled="isCancelDisabled">
              {{ t('common.actions.cancel') }}
            </Button>
          </DrawerClose>
          <Button
            v-if="currentStep === 'import' && importIsCompleted"
            type="button"
            variant="outline"
            @click="open = false"
          >
            {{ t('admin.people.bulk_import.import.actions.close') }}
          </Button>
          <Button
            v-if="currentStep === 'import' && importIsCompleted"
            type="button"
            @click="onViewPeople"
          >
            {{ t('admin.people.bulk_import.import.actions.view_people') }}
          </Button>
          <Button
            v-else-if="showPrimaryButton"
            type="button"
            :disabled="isPrimaryDisabled"
            @click="onPrimaryAction"
          >
            <Loader2 v-if="showPrimaryLoading" class="size-4 animate-spin" />
            {{ primaryButtonLabel }}
          </Button>
        </div>
      </DrawerFooter>
    </DrawerContent>
  </Drawer>
</template>

<script setup lang="ts">
import { computed, toRefs, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import { Download, Loader2, X } from 'lucide-vue-next'
import BulkPeopleImportConfigureStep from '@/components/admin/bulk_people/BulkPeopleImportConfigureStep.vue'
import BulkPeopleImportImportStep from '@/components/admin/bulk_people/BulkPeopleImportImportStep.vue'
import BulkPeopleImportPreviewStep from '@/components/admin/bulk_people/BulkPeopleImportPreviewStep.vue'
import BulkPeopleImportMethodStep from '@/components/admin/bulk_people/BulkPeopleImportMethodStep.vue'
import BulkPeopleImportStepper from '@/components/admin/bulk_people/BulkPeopleImportStepper.vue'
import { useBulkPeopleImportExecution } from '@/lib/composables/bulk_people/useBulkPeopleImportExecution'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
} from '@/components/ui/drawer'
import {
  BULK_PEOPLE_IMPORT_ACCEPT,
  useBulkPeopleImportWizard,
} from '@/lib/composables/bulk_people/useBulkPeopleImportDrawer'

const open = defineModel<boolean>('open', { required: true })

const { t } = useI18n()
const {
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
} = useBulkPeopleImportWizard()

const {
  selectedFile,
  fileError,
  currentStep,
  bulkImport,
  configureForm,
  initialPreview,
  isSubmitting,
  isRefreshingSheet,
  isValidating,
} = toRefs(state)

const {
  summary: importSummary,
  phase: importPhase,
  importValidRowsOnly,
  progress: importProgress,
  logs: importLogs,
  isConfirming,
  hasPendingIssues: importHasPendingIssues,
  canConfirmImport,
  isProcessing: importIsProcessing,
  isCompleted: importIsCompleted,
  isFailed: importIsFailed,
  resetExecutionState,
  resumeIfInProgress,
  confirmImport,
  downloadReport,
  formatLogTime: formatImportLogTime,
} = useBulkPeopleImportExecution({
  bulkImportId: () => bulkImport.value?.id ?? null,
  bulkImportStatus: () => bulkImport.value?.status ?? null,
  previewSummary: () => initialPreview.value?.summary ?? null,
  onBulkImportUpdated: applyBulkImportResponse,
})

watch(open, (isOpen, wasOpen) => {
  if (isOpen && !wasOpen) {
    reset()
    resetExecutionState()
  }
})

watch(currentStep, (step) => {
  if (step === 'import') {
    resumeIfInProgress(bulkImport.value?.status)
  }
})

const showBackButton = computed(() => {
  if (currentStep.value === 'import') return !importIsProcessing.value && !importIsCompleted.value
  return canGoBack.value
})

const isBackDisabled = computed(() => isSubmitting.value || isValidating.value || importIsProcessing.value)

const showCancelButton = computed(() => {
  if (currentStep.value === 'import') return !importIsProcessing.value
  return true
})

const isCancelDisabled = computed(() => isSubmitting.value || isValidating.value || importIsProcessing.value)

const showPrimaryButton = computed(() => {
  if (currentStep.value === 'import') return !importIsCompleted.value
  return true
})

const isPrimaryDisabled = computed(() => {
  if (currentStep.value === 'import') {
    if (importIsFailed.value) return true
    if (importIsProcessing.value || isConfirming.value) return true
    return !canConfirmImport.value
  }
  return !canGoNext.value || isSubmitting.value || isValidating.value
})

const showPrimaryLoading = computed(
  () => isSubmitting.value || isValidating.value || isConfirming.value || importIsProcessing.value,
)

const primaryButtonLabel = computed(() => {
  if (currentStep.value === 'import') {
    if (importIsProcessing.value || isConfirming.value) return t('admin.people.bulk_import.import.actions.importing')
    if (importIsFailed.value) return t('admin.people.bulk_import.import.actions.retry')
    return t('admin.people.bulk_import.import.actions.confirm')
  }
  if (isValidating.value) return t('admin.people.bulk_import.actions.validating')
  if (isSubmitting.value) return t('admin.people.bulk_import.actions.uploading')
  if (isRefreshingSheet.value) return t('admin.people.bulk_import.actions.refreshing_sheet')
  if (currentStep.value === 'preview') return t('admin.people.bulk_import.actions.continue_to_import')
  return t('admin.people.bulk_import.actions.next')
})

function onDownloadTemplate() {
  toast.info(t('admin.people.bulk_import.upload.template_coming_soon'))
}

function onBack() {
  if (currentStep.value === 'import' && !importIsProcessing.value) {
    resetExecutionState()
  }
  goToPreviousStep()
}

function onPrimaryAction() {
  if (currentStep.value === 'import') {
    void confirmImport()
    return
  }
  goToNextStep()
}

function onDownloadImportReport() {
  downloadReport()
}

function onViewPeople() {
  open.value = false
}

function onChangeFile() {
  prepareFileReplacement()
}

function onRefreshSheet(sheet: string) {
  void refreshSheetInspection(sheet)
}
</script>
