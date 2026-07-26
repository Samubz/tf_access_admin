<template>
  <Collapsible v-if="hasChildrenOrUnits" v-model:open="open" class="w-full">
    <div class="group flex min-h-10 items-center gap-1 rounded-lg pr-1 transition-colors hover:bg-muted/50">
      <CollapsibleTrigger as-child>
        <button
          type="button"
          class="flex size-7 shrink-0 items-center justify-center rounded-md hover:bg-muted"
          :aria-label="t('admin.property_setup.step3.manual.actions.toggle')"
        >
          <ChevronRight
            class="text-muted-foreground size-4 shrink-0 transition-transform duration-200"
            :class="{ 'rotate-90': open }"
          />
        </button>
      </CollapsibleTrigger>

      <div class="flex size-8 shrink-0 items-center justify-center rounded-md border border-border/60 bg-muted/50">
        <component :is="iconFor(section.section_type)" class="text-muted-foreground size-4" />
      </div>

      <div class="flex min-w-0 flex-1 items-center gap-2">
        <span class="truncate text-sm font-medium">{{ section.name }}</span>
        <Badge variant="secondary" class="shrink-0 font-normal">{{ typeLabel }}</Badge>
        <Badge variant="outline" class="shrink-0 font-normal">
          {{ t('admin.property_setup.step3.manual.unit_count', { count: unitCount }) }}
        </Badge>
      </div>
    </div>

    <CollapsibleContent>
      <ul class="space-y-0.5 pt-0.5">
        <li v-for="child in section.children" :key="child.id">
          <PropertyDetailSectionRow :section="child" :property-id="propertyId" :can-manage-unit="canManageUnit" />
        </li>
        <li v-for="unit in section.units ?? []" :key="unit.id">
          <PropertyDetailUnitRow :unit="unit" :property-id="propertyId" :can-manage-unit="canManageUnit" />
        </li>
      </ul>
    </CollapsibleContent>
  </Collapsible>

  <div v-else class="flex min-h-10 items-center gap-1 rounded-lg pr-1 transition-colors hover:bg-muted/50">
    <span class="size-7 shrink-0" aria-hidden="true" />

    <div class="flex size-8 shrink-0 items-center justify-center rounded-md border border-border/60 bg-muted/50">
      <component :is="iconFor(section.section_type)" class="text-muted-foreground size-4" />
    </div>

    <div class="flex min-w-0 flex-1 items-center gap-2">
      <span class="truncate text-sm font-medium">{{ section.name }}</span>
      <Badge variant="secondary" class="shrink-0 font-normal">{{ typeLabel }}</Badge>
      <Badge variant="outline" class="shrink-0 font-normal">
        {{ t('admin.property_setup.step3.manual.unit_count', { count: unitCount }) }}
      </Badge>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronRight } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { useSectionTypeIcon } from '@/lib/composables/property_section/useSectionTypeIcon'
import PropertyDetailUnitRow, { type DetailUnitNode } from '@/components/admin/residential_property/PropertyDetailUnitRow.vue'

export type DetailSectionNode = {
  id: string
  name: string
  section_type: string
  children?: DetailSectionNode[]
  units?: DetailUnitNode[]
}

const props = defineProps<{
  section: DetailSectionNode
  propertyId: string
  canManageUnit: boolean
}>()

const { t } = useI18n()
const { iconFor } = useSectionTypeIcon()

const open = ref(false)
const typeLabel = computed(() => t(`admin.property_sections.section_types.${props.section.section_type}`))
// Backend tree nodes always carry a `units` key when unit data is requested,
// even on parent sections (an empty array) — so children must be checked
// first, or a parent's own (always-empty) `units` array wins and reports 0
// instead of summing its descendants (add-property-detail-view).
const unitCount = computed(() => childUnitCount(props.section))
const hasChildrenOrUnits = computed(
  () => (props.section.children?.length ?? 0) > 0 || (props.section.units?.length ?? 0) > 0,
)

function childUnitCount(node: DetailSectionNode): number {
  if (node.children && node.children.length > 0) {
    return node.children.reduce((sum, child) => sum + childUnitCount(child), 0)
  }
  return node.units?.length ?? 0
}
</script>
