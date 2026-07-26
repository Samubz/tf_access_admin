<template>
  <div class="space-y-5">
    <p v-if="selectedMode !== 'manual'" class="text-muted-foreground text-sm">
      {{ t('admin.property_setup.step2.description') }}
    </p>

    <div class="grid gap-3 md:grid-cols-3">
      <button
        v-for="mode in modes"
        :key="mode.id"
        type="button"
        class="rounded-lg border p-4 text-left transition"
        :class="selectedMode === mode.id ? 'border-primary ring-1 ring-primary' : 'hover:border-muted-foreground/40'"
        @click="selectedMode = mode.id"
      >
        <div class="flex items-start gap-3">
          <component :is="mode.icon" class="text-muted-foreground mt-0.5 size-5 shrink-0" />
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <span
                class="inline-flex size-4 shrink-0 items-center justify-center rounded-full border"
                :class="selectedMode === mode.id ? 'border-primary' : 'border-muted-foreground/40'"
              >
                <span v-if="selectedMode === mode.id" class="bg-primary size-2 rounded-full" />
              </span>
              <p class="font-medium">{{ mode.label }}</p>
            </div>
            <p class="text-muted-foreground mt-1 pl-6 text-sm">{{ mode.description }}</p>
          </div>
        </div>
      </button>
    </div>

    <div v-if="fieldError('structure') || fieldError('structure_mode')" class="space-y-2">
      <p v-if="fieldError('structure_mode')" class="text-destructive text-sm">
        {{ translateErrors([fieldError('structure_mode')])[0] }}
      </p>
      <p v-if="fieldError('structure')" class="text-destructive text-sm">
        {{ translateErrors([fieldError('structure')])[0] }}
      </p>
      <p v-if="fieldError('quick_structure')" class="text-destructive text-sm">
        {{ translateErrors([fieldError('quick_structure')])[0] }}
      </p>
    </div>

    <QuickStructureForm
      v-if="selectedMode === 'quick' && structureFormat"
      v-model="quickParams"
      :format="structureFormat"
      :property-type="propertyType"
    />

    <ManualSectionForm
      v-if="selectedMode === 'manual' && propertyId"
      :property-id="propertyId"
      :section-types="sectionTypes"
      :recommended-section-types="recommendedSectionTypes"
      :tree="structureTree"
      :selected-mode="selectedMode"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, toRef, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Box, Layers, Zap } from 'lucide-vue-next'
import QuickStructureForm from '@/components/admin/property_setup/QuickStructureForm.vue'
import ManualSectionForm from '@/components/admin/property_setup/ManualSectionForm.vue'
import type {
  PropertyStructureFormat,
  QuickStructureFormParams,
} from '@/lib/property_setup/structurePreview'
import { usePropertySetupStructurePreview } from '@/lib/composables/usePropertySetupStructurePreview'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { usePropertySetupStepValidation } from '@/lib/composables/property_setup/usePropertySetupStepValidation'
import type { PropertySetupStep2Values } from '@/lib/schemas/property_setup'

const props = defineProps<{
  propertyId?: string
  wizard: Record<string, unknown>
  sectionTypes: string[]
  preview: Record<string, any>
  structureFormat: PropertyStructureFormat | null
  propertyType: string
  manualOnly?: boolean
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const { fieldError, validateStep2 } = usePropertySetupStepValidation()
const initialMode = (props.wizard.structure_mode as string) || 'none'
// A created/configured/active property may have been originally built with
// quick mode; manual-only editing sessions fall back to manual since the
// quick option is no longer offered (enable-wizard-editing-created-state).
const selectedMode = ref(props.manualOnly && initialMode === 'quick' ? 'manual' : initialMode)

// Hydrate from the persisted wizard state so a full page reload restores the
// quick-structure form instead of falling back to blank defaults.
function initialQuickParams(): QuickStructureFormParams {
  const saved = (props.wizard.quick_structure ?? {}) as Record<string, unknown>
  return {
    level_1_count: Number(saved.level_1_count ?? 1),
    level_2_count: Number(saved.level_2_count ?? 1),
    level_1_prefix: (saved.level_1_prefix as string) ?? '',
    level_2_prefix: (saved.level_2_prefix as string) ?? '',
    skip_top_level: Boolean(saved.skip_top_level ?? false),
  }
}

const quickParams = ref<QuickStructureFormParams>(initialQuickParams())

watch(
  () => props.wizard.structure_mode,
  (mode) => {
    if (mode) selectedMode.value = mode as string
  },
)

// When the property type has no mapped format, quick mode is not offered.
watch(
  () => props.structureFormat,
  (format) => {
    if (!format && selectedMode.value === 'quick') selectedMode.value = 'none'
  },
)

const structureTree = computed(() => props.preview?.structure?.tree ?? [])
const sectionsCount = computed(() => structureTree.value.length)

const recommendedSectionTypes = computed(
  () => props.structureFormat?.levels.map((level) => level.section_type) ?? [],
)

const propertyIdRef = toRef(() => props.propertyId)
const quickEnabled = computed(() => selectedMode.value === 'quick' && !!props.structureFormat)
const { nodes: quickNodes, counts: quickCounts } = usePropertySetupStructurePreview(
  propertyIdRef,
  quickParams,
  quickEnabled,
)

const quickPreview = computed(() => ({ nodes: quickNodes.value, counts: quickCounts.value }))

const modes = computed(() => {
  const base = [
    {
      id: 'none',
      icon: Box,
      label: t('admin.property_setup.step2.modes.none.title'),
      description: t('admin.property_setup.step2.modes.none.description'),
    },
    {
      id: 'manual',
      icon: Layers,
      label: t('admin.property_setup.step2.modes.manual.title'),
      description: t('admin.property_setup.step2.modes.manual.description'),
    },
  ]

  if (props.structureFormat && !props.manualOnly) {
    base.push({
      id: 'quick',
      icon: Zap,
      label: t('admin.property_setup.step2.modes.quick.title'),
      description: t('admin.property_setup.step2.modes.quick.description'),
    })
  }

  return base
})

function getValues() {
  return {
    structure_mode: selectedMode.value,
    quick_structure_confirmed: selectedMode.value === 'quick',
    quick_structure: selectedMode.value === 'quick' ? { ...quickParams.value } : undefined,
  }
}

function validate() {
  return validateStep2(getValues() as PropertySetupStep2Values, sectionsCount.value)
}

defineExpose({
  getValues,
  validate,
  selectedMode: computed(() => selectedMode.value),
  quickPreview,
})
</script>
