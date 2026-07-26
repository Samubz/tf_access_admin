<template>
  <Card class="flex flex-col">
    <CardHeader class="shrink-0">
      <CardTitle class="text-base">{{ t('admin.property_setup.step3.preview.title') }}</CardTitle>
    </CardHeader>
    <CardContent class="flex min-h-0 flex-1 flex-col gap-4 text-sm">
      <div class="flex flex-col gap-4">
        <Card v-if="showSummary" class="shrink-0 border bg-muted/40 shadow-none">
          <CardContent class="pt-5">
            <div class="flex items-start gap-3">
              <span class="bg-background inline-flex size-9 shrink-0 items-center justify-center rounded-full border">
                <Users class="text-muted-foreground size-4" />
              </span>
              <div class="min-w-0 space-y-1">
                <p class="text-sm font-semibold">
                  {{ t('admin.property_setup.step3.preview.total_will_create', { count: displayTotalUnits }) }}
                </p>
                <p class="text-muted-foreground text-xs leading-relaxed">{{ summaryExplanation }}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <div v-if="showSummary">
          <p class="text-muted-foreground text-md mb-2">{{ t('admin.property_setup.step3.preview.title') }}</p>
          <Card class="flex min-h-0 flex-1 flex-col border bg-background shadow-none">
            <CardContent class="min-h-0 flex-1 overflow-y-auto p-0">
              <div v-if="loading && !paginatedGroups.length" class="text-muted-foreground p-3 text-sm">
                {{ t('admin.property_setup.step3.preview.loading') }}
              </div>
              <div v-else-if="paginatedGroups.length" class="overflow-x-auto">
                <table class="w-full text-sm">
                  <thead class="bg-muted/50">
                    <tr>
                      <th class="px-3 py-2 text-left font-medium">
                        {{ t('admin.property_setup.step3.preview.table.tower_floor') }}
                      </th>
                      <th class="px-3 py-2 text-left font-medium">
                        {{ t('admin.property_setup.step3.preview.table.units') }}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="row in paginatedGroups" :key="row.label" class="border-t">
                      <td class="px-3 py-2">{{ row.label }}</td>
                      <td class="px-3 py-2">{{ row.identifiers }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p v-else class="text-muted-foreground p-3 text-sm">{{ emptyMessage }}</p>
            </CardContent>
          </Card>

          <div v-if="totalCombinations > 0" class="flex flex-col gap-2 my-2 justify-between text-xs">
            <div class="w-full flex justify-between">
              <Button variant="ghost" size="sm" :disabled="combinationPage <= 1" @click="prevPage">
                {{ t('admin.property_setup.step3.preview.prev') }}
              </Button>
              <Button variant="ghost" size="sm" :disabled="combinationPage >= totalCombinationPages" @click="nextPage">
                {{ t('admin.property_setup.step3.preview.next') }}
              </Button>
            </div>

            <span class="text-muted-foreground text-center">
              {{ t('admin.property_setup.step3.preview.pagination', {
                shown: paginatedGroups.length,
                total: totalCombinations,
              }) }}
            </span>
          </div>
        </div>
        <div v-else>
          <p class="text-muted-foreground text-md mb-2">{{ t('admin.property_setup.step3.preview.import_mode') }}</p>
        </div>
      </div>
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { computed, toRef } from 'vue'
import { useI18n } from 'vue-i18n'
import { Users } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  usePropertySetupUnitsPreview,
  type UnitsPreviewParams,
} from '@/lib/composables/usePropertySetupUnitsPreview'
import type { StructureTreeNode } from '@/lib/property_setup/structurePreview'

const props = defineProps<{
  propertyId?: string
  preview: Record<string, any>
  generationParams?: UnitsPreviewParams
  automaticMode?: boolean
}>()

const { t } = useI18n()

const propertyIdRef = toRef(() => props.propertyId)
const paramsRef = toRef(() => props.generationParams ?? {})
const enabledRef = toRef(() => props.automaticMode === true)
const structureTreeRef = toRef(() => (props.preview?.structure?.tree ?? []) as StructureTreeNode[])
const showSummary = computed(() => props.automaticMode === true)

const {
  loading,
  totalUnits,
  paginatedGroups,
  totalCombinations,
  combinationPage,
  totalCombinationPages,
  nextPage,
  prevPage,
} = usePropertySetupUnitsPreview(propertyIdRef, paramsRef, enabledRef, structureTreeRef)

const displayTotalUnits = computed(() => {
  if (totalUnits.value > 0) return totalUnits.value

  const leafSections = props.preview?.counts?.level_2 ?? 0
  const perLeaf = props.generationParams?.units_per_leaf ?? 4

  // Gate on the leaf level alone: single-level formats and "no towers" buildings
  // legitimately have a zero top-level count while still having real leaf
  // sections (fix-automatic-unit-generation §9.6).
  if (leafSections > 0) return leafSections * perLeaf

  return perLeaf
})

const summaryExplanation = computed(() => {
  const topLevel = props.preview?.counts?.level_1 ?? 0
  const leafSections = props.preview?.counts?.level_2 ?? 0
  const perLeaf = props.generationParams?.units_per_leaf ?? 4

  if (leafSections > 0) {
    return t('admin.property_setup.step3.preview.explanation_with_structure', {
      count: displayTotalUnits.value,
      towers: topLevel,
      floors: leafSections,
      per_floor: perLeaf,
    })
  }

  return t('admin.property_setup.step3.preview.explanation_flat', { count: displayTotalUnits.value })
})

const emptyMessage = computed(() => t('admin.property_setup.step3.preview.empty'))
</script>
