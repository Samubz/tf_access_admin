<template>
  <Collapsible v-if="hasUnits" v-model:open="open" class="w-full">
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

      <Button
        v-if="eligible"
        type="button"
        variant="ghost"
        size="sm"
        class="shrink-0 opacity-70 transition-opacity group-hover:opacity-100"
        @click="emit('add-unit', section)"
      >
        <Plus class="size-4" />
        {{ t('admin.property_setup.step3.manual.add_unit') }}
      </Button>
    </div>

    <CollapsibleContent>
      <ul class="space-y-0.5 pt-0.5">
        <li v-for="unit in section.units" :key="unit.id">
          <UnitTreeRow
            :unit="unit"
            :property-id="propertyId"
            @edit="emit('edit', $event)"
            @delete="emit('delete', $event)"
          />
        </li>
      </ul>
    </CollapsibleContent>
  </Collapsible>

  <div v-else class="group flex min-h-10 items-center gap-1 rounded-lg pr-1 transition-colors hover:bg-muted/50">
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

    <Button
      v-if="eligible"
      type="button"
      variant="ghost"
      size="sm"
      class="shrink-0 opacity-70 transition-opacity group-hover:opacity-100"
      @click="emit('add-unit', section)"
    >
      <Plus class="size-4" />
      {{ t('admin.property_setup.step3.manual.add_unit') }}
    </Button>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronRight, Plus } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { useSectionTypeIcon } from '@/lib/composables/property_section/useSectionTypeIcon'
import UnitTreeRow, { type UnitNode } from '@/components/admin/property_setup/UnitTreeRow.vue'

type SectionNode = {
  id: string
  name: string
  section_type: string
  children?: SectionNode[]
  units?: UnitNode[]
}

const props = defineProps<{
  section: SectionNode
  eligible: boolean
  propertyId?: string
}>()

const emit = defineEmits<{
  (e: 'add-unit', section: SectionNode): void
  (e: 'edit', unit: UnitNode): void
  (e: 'delete', unit: UnitNode): void
}>()

const { t } = useI18n()
const { iconFor } = useSectionTypeIcon()

const open = ref(true)
const typeLabel = computed(() => t(`admin.property_sections.section_types.${props.section.section_type}`))
const unitCount = computed(() => props.section.units?.length ?? 0)
const hasUnits = computed(() => unitCount.value > 0)
</script>
