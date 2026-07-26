<template>
  <div class="space-y-5">
    <div class="bg-muted flex flex-wrap items-center gap-x-3 gap-y-1 rounded-md px-3 py-2 text-sm">
      <span class="flex items-center gap-1.5 font-medium">
        <Building2 class="size-3.5 shrink-0" />
        {{ property?.name }}
      </span>
      <template v-if="towerCount">
        <span class="text-muted-foreground" aria-hidden="true">|</span>
        <span class="text-muted-foreground flex items-center gap-1.5">
          <Building class="size-3.5 shrink-0" />
          {{ topLevelLabel }}
        </span>
      </template>
      <template v-if="floorCount">
        <span class="text-muted-foreground" aria-hidden="true">|</span>
        <span class="text-muted-foreground flex items-center gap-1.5">
          <Layers class="size-3.5 shrink-0" />
          {{ leafLevelLabel }}
        </span>
      </template>
    </div>

    <div class="space-y-5">
        <div class="space-y-3">
          <p class="text-muted-foreground text-sm">{{ t('admin.property_setup.step3.description') }}</p>

          <div class="grid gap-3 md:grid-cols-2">
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
        </div>

        <section v-if="selectedMode === 'automatic'" class="space-y-4 rounded-lg border p-4">
          <h3 class="text-sm font-medium">{{ t('admin.property_setup.step3.automatic.title') }}</h3>
          <div class="grid gap-4 md:grid-cols-2">
            <Field :data-invalid="!!fieldError('unit_generation.unit_type')">
              <FieldLabel>{{ t('admin.property_setup.step3.automatic.unit_type') }}</FieldLabel>
              <Select v-model="autoForm.unit_type">
                <SelectTrigger class="w-full" :aria-invalid="!!fieldError('unit_generation.unit_type')">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem v-for="type in unitTypes" :key="type" :value="type">
                    {{ t(`admin.units.unit_types.${type}`) }}
                  </SelectItem>
                </SelectContent>
              </Select>
              <FieldError
                v-if="fieldError('unit_generation.unit_type')"
                :errors="translateErrors([fieldError('unit_generation.unit_type')])"
              />
            </Field>
            <Field :data-invalid="!!fieldError('unit_generation.identifier_format')">
              <FieldLabel>{{ t('admin.property_setup.step3.automatic.identifier_format') }}</FieldLabel>
              <Select v-model="autoForm.identifier_format">
                <SelectTrigger class="w-full" :aria-invalid="!!fieldError('unit_generation.identifier_format')">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem
                    v-for="opt in identifierFormatOptions"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </SelectItem>
                </SelectContent>
              </Select>
              <FieldError
                v-if="fieldError('unit_generation.identifier_format')"
                :errors="translateErrors([fieldError('unit_generation.identifier_format')])"
              />
            </Field>
            <Field>
              <FieldLabel>{{ t('admin.property_setup.step3.automatic.example') }}</FieldLabel>
              <Input :model-value="exampleIdentifiers" readonly class="bg-muted" />
            </Field>
            <Field :data-invalid="!!fieldError('unit_generation.units_per_leaf')">
              <FieldLabel>{{ unitsPerLeafLabel }}</FieldLabel>
              <Input
                v-model.number="autoForm.units_per_leaf"
                type="number"
                min="1"
                :aria-invalid="!!fieldError('unit_generation.units_per_leaf')"
              />
              <FieldError
                v-if="fieldError('unit_generation.units_per_leaf')"
                :errors="translateErrors([fieldError('unit_generation.units_per_leaf')])"
              />
            </Field>
          </div>
          <div class="flex items-center justify-between gap-3 rounded-md border px-3 py-2.5 text-sm">
            <div>
              <p class="font-medium">{{ t('admin.property_setup.step3.automatic.parking.title') }}</p>
              <p class="text-muted-foreground text-xs">{{ t('admin.property_setup.step3.automatic.parking.hint') }}</p>
            </div>
            <span
              class="bg-muted relative inline-flex h-5 w-9 shrink-0 cursor-not-allowed rounded-full opacity-50"
              aria-hidden="true"
            >
              <span class="bg-background absolute top-0.5 left-0.5 size-4 rounded-full border shadow-sm" />
            </span>
          </div>
        </section>

        <section v-else-if="selectedMode === 'manual' && propertyId" class="rounded-lg border p-4">
          <ManualUnitsForm :property-id="propertyId" :unit-types="unitTypes" :tree="sectionTree" />
        </section>

        <section v-else-if="selectedMode === 'import' && propertyId" class="space-y-3 rounded-lg border p-4">
          <p class="text-muted-foreground text-sm">{{ t('admin.property_setup.step3.import.description') }}</p>
          <Button variant="outline" @click="importOpen = true">
            {{ t('admin.property_setup.step3.import.open') }}
          </Button>
          <BulkUnitsImportDrawer
            v-model:open="importOpen"
            :property-name="String(property?.name ?? '')"
            :residential-property-id="propertyId"
            property-section-id=""
            :section-tree="sectionTree"
            :selected-section="null"
          />
        </section>

        <div v-if="issues.length || fieldError('units_mode')" class="space-y-2">
          <p v-if="fieldError('units_mode')" class="text-destructive text-sm">
            {{ translateErrors([fieldError('units_mode')])[0] }}
          </p>
          <p v-for="issue in issues" :key="issue" class="text-destructive text-sm">{{ issue }}</p>
        </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building, Building2, FileSpreadsheet, Layers, ListTree, Sparkles } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Field, FieldError, FieldLabel } from '@/components/ui/field'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import BulkUnitsImportDrawer from '@/components/admin/bulk_units/BulkUnitsImportDrawer.vue'
import ManualUnitsForm from '@/components/admin/property_setup/ManualUnitsForm.vue'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { usePropertySetupStepValidation } from '@/lib/composables/property_setup/usePropertySetupStepValidation'
import type { PropertySetupStep3Values } from '@/lib/schemas/property_setup'
import { buildTreeWithUnits, buildUnitsPreviewFromTree, countUnitsPreviewGroups } from '@/lib/property_setup/unitsPreview'

const props = defineProps<{
  property: Record<string, unknown> | null
  wizard: Record<string, unknown>
  unitTypes: string[]
  preview: Record<string, any>
  errors?: Record<string, string[]>
  structureMode?: string
  unitsIn?: string | null
  manualOnly?: boolean
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const { fieldError, validateStep3, setFieldErrors } = usePropertySetupStepValidation()
const importOpen = ref(false)

const UNIT_ELIGIBLE_TYPES = ['block', 'tower', 'floor']
const sectionTree = computed(() => props.preview?.structure?.tree ?? [])
const hasEligibleSections = computed(() =>
  flattenSectionTree(sectionTree.value).some(
    (section: Record<string, unknown>) =>
      ((section.children as unknown[] | undefined)?.length ?? 0) === 0 &&
      UNIT_ELIGIBLE_TYPES.includes(section.section_type as string),
  ),
)

function flattenSectionTree(nodes: Record<string, unknown>[]): Record<string, unknown>[] {
  return nodes.flatMap((node) => [node, ...((node.children as Record<string, unknown>[] | undefined) ?? [])])
}

// Manual is preferred whenever the property already has persisted units, or
// when eligible sections exist but the structure did not come from quick mode
// (quick structures default to automatic). No persisted mode falls back to
// automatic for a fresh quick setup, or import when no sections are eligible.
function defaultUnitsMode() {
  const persisted = props.wizard.units_mode as string | undefined
  if (persisted && !(props.manualOnly && persisted === 'automatic')) return persisted

  const persistedUnitsCount = Number(props.preview?.counts?.units ?? 0)
  if (persistedUnitsCount > 0) return 'manual'
  if (props.structureMode === 'quick' && !props.manualOnly) return 'automatic'
  return hasEligibleSections.value ? 'manual' : 'import'
}

const selectedMode = ref(defaultUnitsMode())

// Default identifier format derived from the property's leaf type when no value
// was persisted yet.
function defaultIdentifierFormat() {
  return props.unitsIn === 'block' ? 'block_sequential' : 'floor_sequential'
}

// Hydrate the automatic-generation form from the persisted wizard state so a
// full page reload restores step 3 instead of showing blank defaults.
function initialAutoForm() {
  const saved = (props.wizard.unit_generation ?? {}) as Record<string, unknown>
  return {
    unit_type: (saved.unit_type as string) ?? 'apartment',
    identifier_format: (saved.identifier_format as string) ?? defaultIdentifierFormat(),
    units_per_leaf: Number(saved.units_per_leaf ?? 4),
  }
}

const autoForm = reactive(initialAutoForm())

watch(
  () => [props.wizard.units_mode, props.structureMode] as const,
  ([mode]) => {
    if (mode) {
      selectedMode.value = mode as string
      return
    }
    selectedMode.value = defaultUnitsMode()
  },
  { immediate: true },
)

// When the property's leaf type changes after mount (e.g. the user changed the
// property type), reset the identifier format to a valid default for the new
// leaf type. The initial default is already applied by initialAutoForm().
watch(
  () => props.unitsIn,
  (val) => {
    autoForm.identifier_format = val === 'block' ? 'block_sequential' : 'floor_sequential'
  },
)

watch(
  () => props.errors,
  (errors) => {
    if (!errors) return
    const mapped = Object.fromEntries(
      Object.entries(errors).map(([key, messages]) => [key, messages[0]]),
    )
    setFieldErrors(mapped)
  },
  { immediate: true, deep: true },
)

const propertyId = computed(() => props.property?.id as string | undefined)
const towerCount = computed(() => props.preview?.counts?.level_1 ?? 0)
const floorCount = computed(() => props.preview?.counts?.level_2 ?? 0)

// Floor-based structures keep the "towers"/"floors" wording; other leaf types
// (e.g. sector/block) fall back to the generic section-count phrasing so the
// context bar is never mislabeled (fix-automatic-unit-generation §9.3).
const topLevelLabel = computed(() =>
  props.unitsIn === 'floor'
    ? t('admin.property_setup.step3.context.towers', { count: towerCount.value })
    : t('admin.property_setup.step3.context.structure_count', { count: towerCount.value }),
)
const leafLevelLabel = computed(() =>
  props.unitsIn === 'floor'
    ? t('admin.property_setup.step3.context.floors', { count: floorCount.value })
    : t('admin.property_setup.step3.context.structure_count', { count: floorCount.value }),
)

const identifierFormatOptions = computed(() => {
  const base = [
    { value: 'floor_sequential', label: t('admin.property_setup.step3.automatic.formats.floor_sequential') },
    { value: 'sequential', label: t('admin.property_setup.step3.automatic.formats.sequential') },
  ]
  if (props.unitsIn === 'block') {
    return [
      { value: 'block_sequential', label: t('admin.property_setup.step3.automatic.formats.block_sequential') },
      { value: 'sequential', label: t('admin.property_setup.step3.automatic.formats.sequential') },
    ]
  }
  return base
})

const unitsPerLeafLabel = computed(() =>
  props.unitsIn === 'block'
    ? t('admin.property_setup.step3.automatic.units_per_block')
    : t('admin.property_setup.step3.automatic.units_per_floor'),
)

const exampleIdentifiers = computed(() => {
  const qty = Math.max(autoForm.units_per_leaf, 1)
  if (autoForm.identifier_format === 'floor_sequential') {
    return Array.from({ length: qty }, (_, index) => 101 + index).join(', ')
  }
  if (autoForm.identifier_format === 'block_sequential') {
    return Array.from({ length: qty }, (_, index) => `B${101 + index}`).join(', ')
  }
  return Array.from({ length: qty }, (_, index) => index + 1).join(', ')
})

const previewParams = computed(() => ({
  unit_type: autoForm.unit_type,
  identifier_format: autoForm.identifier_format,
  units_per_leaf: autoForm.units_per_leaf,
}))

const isAutomaticMode = computed(() => selectedMode.value === 'automatic')

const issues = computed(() => {
  const list: string[] = []
  if (props.errors) {
    Object.values(props.errors).forEach((messages) => list.push(...messages))
  }
  if (props.preview?.warnings?.length) list.push(...props.preview.warnings)
  return list
})

const isQuickStructure = computed(() => props.structureMode === 'quick' && !props.manualOnly)

const modes = computed(() => {
  const list = []
  if (isQuickStructure.value) {
    list.push({
      id: 'automatic',
      icon: Sparkles,
      label: t('admin.property_setup.step3.modes.automatic.title'),
      description: t('admin.property_setup.step3.modes.automatic.description'),
    })
  }
  if (hasEligibleSections.value) {
    list.push({
      id: 'manual',
      icon: ListTree,
      label: t('admin.property_setup.step3.modes.manual.title'),
      description: t('admin.property_setup.step3.modes.manual.description'),
    })
  }
  list.push({
    id: 'import',
    icon: FileSpreadsheet,
    label: t('admin.property_setup.step3.modes.import.title'),
    description: t('admin.property_setup.step3.modes.import.description'),
  })
  return list
})

const estimatedUnitsCount = computed(() => {
  if (selectedMode.value !== 'automatic') return null
  return countUnitsPreviewGroups(buildUnitsPreviewFromTree(sectionTree.value, previewParams.value))
})

function getValues() {
  if (selectedMode.value === 'automatic') {
    return {
      units_mode: selectedMode.value,
      unit_generation: { ...autoForm },
    }
  }

  return {
    units_mode: selectedMode.value,
    unit_generation: {
      unit_type: autoForm.unit_type,
      units_per_leaf: autoForm.units_per_leaf,
    },
  }
}

function validate() {
  return validateStep3(getValues() as PropertySetupStep3Values)
}

const clientPreviewTree = computed(() => {
  if (selectedMode.value !== 'automatic') return undefined
  return buildTreeWithUnits(sectionTree.value, previewParams.value)
})

defineExpose({ getValues, previewParams, isAutomaticMode, validate, estimatedUnitsCount, clientPreviewTree })
</script>
