<template>
  <div class="space-y-6">
    <div class="space-y-6 rounded-lg border bg-card p-5">
      <div class="space-y-1">
        <h3 class="text-base font-semibold">{{ t('admin.people.bulk_import.upload.title') }}</h3>
        <p class="text-sm text-muted-foreground">{{ t('admin.people.bulk_import.upload.subtitle') }}</p>
      </div>

      <div class="grid gap-6 lg:grid-cols-6">
        <div class="col-span-2 space-y-1">
          <p class="text-sm font-medium">{{ t('admin.people.bulk_import.upload.step_download') }}</p>
          <p class="text-xs text-muted-foreground">
            {{ t('admin.people.bulk_import.upload.step_download_description') }}
          </p>
          <Button type="button" variant="outline" class="w-full justify-start" @click="emit('download-template')">
            <Download class="size-4" />
            {{ t('admin.people.bulk_import.upload.download_button') }}
          </Button>
        </div>

        <div class="col-span-4 space-y-1">
          <p class="text-sm font-medium">{{ t('admin.people.bulk_import.upload.step_upload') }}</p>
          <p class="text-xs text-muted-foreground">{{ t('admin.people.bulk_import.upload.formats') }}</p>
          <BulkUnitsFileDropzone
            :accept="excelAccept"
            :selected-file="selectedFile"
            :error="fileError"
            :title="t('admin.people.bulk_import.upload.dropzone_title')"
            :subtitle="t('admin.people.bulk_import.upload.dropzone_subtitle')"
            :browse-label="t('admin.people.bulk_import.upload.dropzone_aria')"
            :remove-label="t('admin.people.bulk_import.upload.remove_file')"
            :invalid-type-message="t('admin.people.bulk_import.upload.invalid_type')"
            @update:selected-file="selectedFile = $event"
            @update:error="fileError = $event"
          />
        </div>
      </div>

      <Alert class="border-sky-200 bg-sky-50 text-sky-950 dark:border-sky-900/50 dark:bg-sky-950/40 dark:text-sky-100">
        <Info class="text-sky-600 dark:text-sky-300" />
        <AlertTitle>{{ t('admin.people.bulk_import.requirements.title') }}</AlertTitle>
        <AlertDescription class="text-sky-900/90 dark:text-sky-100/90">
          <ul class="list-disc space-y-1 pl-4">
            <li v-for="(item, index) in requirementItems" :key="index">{{ item }}</li>
          </ul>
        </AlertDescription>
      </Alert>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Download, Info } from 'lucide-vue-next'
import BulkUnitsFileDropzone from '@/components/admin/bulk_units/BulkUnitsFileDropzone.vue'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'

const selectedFile = defineModel<File | null>('selectedFile', { required: true })
const fileError = defineModel<string | null>('fileError', { required: true })

defineProps<{
  excelAccept: string
}>()

const emit = defineEmits<{
  (e: 'download-template'): void
}>()

const { t, tm, rt } = useI18n()

const requirementItems = computed(() => {
  const messages = tm('admin.people.bulk_import.requirements.items')
  if (!Array.isArray(messages)) return []
  return messages.map((item) => rt(item))
})
</script>
