<template>
  <nav class="w-full" :aria-label="t('admin.people.bulk_import.steps_nav')">
    <ol class="flex w-full items-start">
      <li v-for="(step, index) in steps" :key="step.id" class="flex min-w-0 flex-1 items-start">
        <div class="flex min-w-0 flex-1 flex-col items-center gap-1.5 text-center">
          <span
            class="inline-flex size-8 shrink-0 items-center justify-center rounded-full text-xs font-semibold transition-colors"
            :class="indicatorClass(index)"
          >
            <Check v-if="index < stepIndex" class="size-4" aria-hidden="true" />
            <span v-else>{{ index + 1 }}</span>
          </span>
          <span
            class="hidden truncate text-xs font-medium sm:block sm:text-sm"
            :class="index <= stepIndex ? 'text-foreground' : 'text-muted-foreground'"
          >
            {{ step.label }}
          </span>
        </div>
        <div
          v-if="index < steps.length - 1"
          class="mx-1 mt-4 hidden h-px flex-1 bg-border sm:block"
          aria-hidden="true"
        />
      </li>
    </ol>
  </nav>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check } from 'lucide-vue-next'
import { BULK_PEOPLE_IMPORT_STEPS } from '@/lib/composables/bulk_people/useBulkPeopleImportDrawer'

const props = defineProps<{
  stepIndex: number
}>()

const { t } = useI18n()

const steps = computed(() =>
  BULK_PEOPLE_IMPORT_STEPS.map((id) => ({
    id,
    label: t(`admin.people.bulk_import.steps.${id}`),
  })),
)

function indicatorClass(index: number) {
  if (index < props.stepIndex) return 'bg-accent text-accent-foreground'
  if (index === props.stepIndex) return 'bg-primary text-primary-foreground'
  return 'bg-muted text-muted-foreground'
}
</script>
