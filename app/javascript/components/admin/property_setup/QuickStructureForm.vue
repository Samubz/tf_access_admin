<template>
  <section class="space-y-4 rounded-lg border p-4">
    <h3 class="text-sm font-medium">{{ t('admin.property_setup.step2.quick.title') }}</h3>

    <label
      v-if="showTowerToggle"
      class="flex items-center gap-2 text-sm"
    >
      <input v-model="hasTopLevel" type="checkbox" class="size-4 rounded border" />
      {{ t('admin.property_setup.step2.quick.has_towers') }}
    </label>

    <div
      v-for="level in effectiveLevels"
      :key="level.section_type"
      class="grid gap-3 md:grid-cols-2"
    >
      <Field>
        <FieldLabel>
          {{ t('admin.property_setup.step2.quick.count', { section: sectionLabel(level) }) }}
        </FieldLabel>
        <Input v-model.number="counts[level.section_type]" type="number" min="1" />
      </Field>
      <Field>
        <FieldLabel>
          {{ t('admin.property_setup.step2.quick.prefix', { section: sectionLabel(level) }) }}
        </FieldLabel>
        <Input v-model="prefixes[level.section_type]" />
      </Field>
    </div>

    <Alert>
      <Info class="size-4" />
      <AlertDescription>{{ t('admin.property_setup.step2.quick.info') }}</AlertDescription>
    </Alert>
  </section>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Info } from 'lucide-vue-next'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Input } from '@/components/ui/input'
import { Field, FieldLabel } from '@/components/ui/field'
import type {
  PropertyStructureFormat,
  StructureFormatLevel,
  QuickStructureFormParams,
} from '@/lib/property_setup/structurePreview'

const props = defineProps<{
  format: PropertyStructureFormat
  propertyType: string
  modelValue?: QuickStructureFormParams
}>()

const emit = defineEmits<{
  'update:modelValue': [value: QuickStructureFormParams]
}>()

const { t } = useI18n()

const counts = reactive<Record<string, number>>({})
const prefixes = reactive<Record<string, string>>({})
const hasTopLevel = ref(true)

function sectionLabel(level: StructureFormatLevel): string {
  return t(`admin.property_sections.section_types.${level.section_type}`)
}

const isTwoLevel = computed(() => props.format.levels.length === 2)
const showTowerToggle = computed(() => props.propertyType === 'building' && isTwoLevel.value)

const skipTopLevel = computed(() => showTowerToggle.value && !hasTopLevel.value)

const effectiveLevels = computed<StructureFormatLevel[]>(() => {
  if (skipTopLevel.value) return [props.format.levels[props.format.levels.length - 1]]
  return props.format.levels
})

// Seed each level from the persisted modelValue when present (so a page reload
// restores the form), otherwise fall back to count=1 and a section-derived
// prefix. modelValue is keyed by level position (level_1/level_2) while internal
// state is keyed by section_type, so map by index.
watch(
  () => props.format,
  (format) => {
    const saved = props.modelValue
    format.levels.forEach((level, index) => {
      const savedCount = index === 0 ? saved?.level_1_count : saved?.level_2_count
      const savedPrefix = index === 0 ? saved?.level_1_prefix : saved?.level_2_prefix
      if (counts[level.section_type] == null) counts[level.section_type] = savedCount ?? 1
      if (prefixes[level.section_type] == null) prefixes[level.section_type] = savedPrefix || sectionLabel(level)
    })
    if (saved?.skip_top_level != null) hasTopLevel.value = !saved.skip_top_level
  },
  { immediate: true },
)

const params = computed<QuickStructureFormParams>(() => {
  const levels = effectiveLevels.value
  const top = levels[0]
  const leaf = levels[1]

  return {
    level_1_count: counts[top.section_type] ?? 1,
    level_2_count: leaf ? (counts[leaf.section_type] ?? 1) : 1,
    level_1_prefix: prefixes[top.section_type] ?? '',
    level_2_prefix: leaf ? (prefixes[leaf.section_type] ?? '') : '',
    skip_top_level: skipTopLevel.value,
  }
})

watch(params, (value) => emit('update:modelValue', value), { immediate: true, deep: true })
</script>
