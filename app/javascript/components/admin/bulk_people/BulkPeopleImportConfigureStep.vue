<template>
  <div class="space-y-6">
    <div>
      <h3 class="text-base font-semibold">{{ t('admin.people.bulk_import.configure.title') }}</h3>
      <p class="text-xs text-muted-foreground">{{ t('admin.people.bulk_import.configure.subtitle') }}</p>
    </div>

    <form class="space-y-6" @submit.prevent>
      <div class="grid gap-6 lg:grid-cols-2">
        <div class="space-y-6">
          <Card class="py-4">
            <CardContent class="space-y-2 px-4">
              <p class="text-sm font-medium">{{ t('admin.people.bulk_import.configure.uploaded_file') }}</p>
              <div class="flex items-start gap-3 rounded-lg border bg-muted/30 p-3">
                <div
                  class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-green-100 text-green-700 dark:bg-green-950 dark:text-green-300"
                >
                  <FileSpreadsheet class="size-5" aria-hidden="true" />
                </div>
                <div class="min-w-0 flex-1 space-y-1">
                  <p class="truncate text-sm font-medium">{{ bulkImport.original_filename }}</p>
                  <p class="text-xs text-muted-foreground">{{ formattedFileSize }}</p>
                </div>
                <Badge variant="secondary" class="shrink-0 border-green-200 bg-green-50 text-green-800">
                  {{ t('admin.people.bulk_import.configure.uploaded_badge') }}
                </Badge>
              </div>
              <Button type="button" variant="link" class="mt-2 h-auto p-0" @click="emit('change-file')">
                <Upload class="size-4" />
                {{ t('admin.people.bulk_import.configure.change_file') }}
              </Button>
            </CardContent>
          </Card>

          <Card class="py-4">
            <CardContent class="space-y-4 px-4">
              <p class="text-sm font-medium">{{ t('admin.people.bulk_import.configure.mapping_options') }}</p>

              <VeeField v-slot="{ field, errors }" name="selected_sheet">
                <Field :data-invalid="!!errors.length">
                  <FieldLabel for="bulk-people-import-sheet">
                    {{ t('admin.people.bulk_import.configure.sheet_label') }}
                  </FieldLabel>
                  <Select :model-value="field.value" :disabled="isRefreshingSheet" @update:model-value="onSheetChange">
                    <SelectTrigger id="bulk-people-import-sheet" class="w-full">
                      <SelectValue :placeholder="t('admin.people.bulk_import.configure.sheet_placeholder')" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem v-for="sheet in sheetOptions" :key="sheet" :value="sheet">
                        {{ sheet }}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                  <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
                </Field>
              </VeeField>

              <VeeField v-slot="{ field, errors }" name="import_mode">
                <Field :data-invalid="!!errors.length">
                  <FieldLabel for="bulk-people-import-mode">
                    {{ t('admin.people.bulk_import.configure.import_mode_label') }}
                  </FieldLabel>
                  <Select :model-value="field.value" @update:model-value="field.onChange">
                    <SelectTrigger id="bulk-people-import-mode" class="w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem v-for="mode in importModeOptions" :key="mode.value" :value="mode.value">
                        {{ mode.label }}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                  <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
                </Field>
              </VeeField>
            </CardContent>
          </Card>
        </div>

        <div class="space-y-6">
          <Card class="py-4">
            <CardContent class="space-y-4 px-4">
              <p class="text-sm font-medium">{{ t('admin.people.bulk_import.configure.detected_columns') }}</p>

              <FieldError v-if="columnMappingsError" :errors="translateErrors([columnMappingsError])" />

              <div class="overflow-hidden rounded-lg border" :class="{ 'opacity-60': isRefreshingSheet }">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead class="text-xs">
                        {{ t('admin.people.bulk_import.configure.table.excel_column') }}
                      </TableHead>
                      <TableHead class="text-xs">
                        {{ t('admin.people.bulk_import.configure.table.system_field') }}
                      </TableHead>
                      <TableHead class="w-24 text-right text-xs" />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    <TableRow v-for="mapping in columnMappings" :key="mapping.target" :class="mappingRowClass(mapping)">
                      <TableCell class="text-sm text-muted-foreground">{{ mapping.source ?? '—' }}</TableCell>
                      <TableCell class="text-sm font-medium">
                        {{ t(`admin.people.bulk_import.configure.fields.${mapping.target}`) }}
                      </TableCell>
                      <TableCell class="text-right">
                        <Badge v-if="mapping.required && !mapping.matched" variant="destructive" class="text-xs">
                          {{ t('admin.people.bulk_import.configure.missing_badge') }}
                        </Badge>
                        <Badge v-else-if="mapping.matched" variant="success" class="text-xs">
                          {{ t('admin.people.bulk_import.configure.matched_badge') }}
                        </Badge>
                        <Badge v-else-if="mapping.required" variant="outline" class="text-xs">
                          {{ t('admin.people.bulk_import.configure.required_badge') }}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>

          <Alert class="border-sky-200 bg-sky-50 text-sky-950 dark:border-sky-900/50 dark:bg-sky-950/40 dark:text-sky-100">
            <Info class="text-sky-600 dark:text-sky-300" />
            <AlertTitle>{{ t('admin.people.bulk_import.configure.validation_rules.title') }}</AlertTitle>
            <AlertDescription class="text-sky-900/90 dark:text-sky-100/90">
              <ul class="space-y-2">
                <li v-for="(rule, index) in validationRules" :key="index" class="flex items-start gap-2 text-sm">
                  <Check class="mt-0.5 size-4 shrink-0 text-sky-600 dark:text-sky-300" />
                  <span>{{ rule }}</span>
                </li>
              </ul>
            </AlertDescription>
          </Alert>
        </div>
      </div>
    </form>
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue'
import { toTypedSchema } from '@vee-validate/zod'
import { useForm, Field as VeeField } from 'vee-validate'
import { useI18n } from 'vue-i18n'
import { Check, FileSpreadsheet, Info, Upload } from 'lucide-vue-next'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Field, FieldError, FieldLabel } from '@/components/ui/field'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { BULK_PEOPLE_IMPORT_REQUIRED_TARGETS } from '@/lib/constants/bulk_import'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { createBulkPeopleImportConfigureSchema } from '@/lib/schemas/bulk_people_import_configure'
import type { BulkPeopleImportConfigureForm } from '@/lib/composables/bulk_people/useBulkPeopleImportDrawer'
import type { BulkImportColumnMapping, BulkImportRecord } from '@/types/bulk_import'

const props = defineProps<{
  bulkImport: BulkImportRecord
  configureForm: BulkPeopleImportConfigureForm
  isRefreshingSheet: boolean
}>()

const emit = defineEmits<{
  (e: 'change-file'): void
  (e: 'refresh-sheet', sheet: string): void
  (e: 'update:configureForm', value: BulkPeopleImportConfigureForm): void
  (e: 'valid-change', valid: boolean): void
}>()

const { t, tm, rt } = useI18n()
const { translateErrors } = useTranslateErrors()

const columnMappings = computed(() => props.bulkImport.metadata.column_mappings)

const validationSchema = computed(() => toTypedSchema(createBulkPeopleImportConfigureSchema(columnMappings.value)))

const { values, meta, errors, setFieldValue, resetForm, validate } = useForm({
  validationSchema,
  initialValues: props.configureForm,
})

watch(
  () => props.configureForm,
  (formValues) => resetForm({ values: formValues }),
)

watch(
  () => props.bulkImport.metadata.column_mappings,
  () => void validate(),
  { deep: true },
)

watch(
  values,
  (formValues) => emit('update:configureForm', { ...formValues } as BulkPeopleImportConfigureForm),
  { deep: true },
)

watch(
  () => meta.value.valid,
  (valid) => emit('valid-change', valid),
  { immediate: true },
)

const sheetOptions = computed(() => props.bulkImport.metadata.file_inspection.sheets)

const columnMappingsError = computed(() => {
  const bag = errors.value as Record<string, string | undefined>
  return bag.column_mappings
})

const formattedFileSize = computed(() => {
  const bytes = props.bulkImport.file_size
  if (!bytes) return ''
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
})

const importModeOptions = computed(() => [
  {
    value: 'create_skip_duplicates',
    label: t('admin.people.bulk_import.configure.import_modes.create_skip_duplicates'),
  },
  { value: 'create_only', label: t('admin.people.bulk_import.configure.import_modes.create_only') },
])

const validationRules = computed(() => {
  const messages = tm('admin.people.bulk_import.configure.validation_rules.items')
  if (!Array.isArray(messages)) return []
  return messages.map((item) => rt(item))
})

function mappingRowClass(mapping: BulkImportColumnMapping) {
  if (
    mapping.required &&
    !mapping.matched &&
    BULK_PEOPLE_IMPORT_REQUIRED_TARGETS.includes(mapping.target as (typeof BULK_PEOPLE_IMPORT_REQUIRED_TARGETS)[number])
  ) {
    return 'bg-destructive/5'
  }
  return undefined
}

function onSheetChange(sheet: unknown) {
  if (typeof sheet !== 'string' || !sheet) return

  const current = values.selected_sheet
  setFieldValue('selected_sheet', sheet)
  if (sheet !== current) {
    emit('refresh-sheet', sheet)
  }
}
</script>
