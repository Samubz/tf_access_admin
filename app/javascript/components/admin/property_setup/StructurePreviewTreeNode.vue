<template>
  <li class="list-none">
    <Collapsible v-model:open="open" class="w-full">
      <CollapsibleTrigger
        v-if="isCollapsible"
        class="hover:bg-muted/50 flex w-full items-center gap-2 rounded-md px-1 py-1.5 text-left"
      >
        <ChevronRight
          class="text-muted-foreground size-4 shrink-0 transition-transform duration-200"
          :class="{ 'rotate-90': open }"
        />
        <Building2 class="text-muted-foreground size-4 shrink-0" />
        <span class="text-sm font-medium">{{ node.name }}</span>
      </CollapsibleTrigger>

      <div v-else class="flex items-center gap-2 px-1 py-1.5">
        <span class="size-4 shrink-0" aria-hidden="true" />
        <Building2 class="text-muted-foreground size-4 shrink-0" />
        <span class="text-sm font-medium">{{ node.name }}</span>
      </div>

      <CollapsibleContent v-if="isCollapsible">
        <ul class="text-muted-foreground mt-1 ml-3 space-y-1 border-l border-dashed pl-4">
          <!-- Nested section children -->
          <template v-if="hasChildren">
            <li
              v-for="item in visibleChildren"
              :key="item.kind === 'ellipsis' ? `${node.id}-ellipsis` : item.node.id"
              class="relative list-none"
            >
              <span
                class="bg-border absolute top-1/2 -left-4 h-px w-3 -translate-y-1/2"
                aria-hidden="true"
              />
              <StructurePreviewTreeNode
                v-if="item.kind === 'child'"
                :node="item.node"
              />
              <div v-else class="flex items-center gap-2 py-0.5">
                <Layers class="size-3.5 shrink-0" />
                <span class="text-sm">...</span>
              </div>
            </li>
          </template>

          <!-- Projected units inside leaf nodes -->
          <template v-if="hasUnits">
            <li
              v-for="(uid, i) in visibleUnits"
              :key="`unit-${i}`"
              class="relative flex items-center gap-2 py-0.5"
            >
              <span
                class="bg-border absolute top-1/2 -left-4 h-px w-3 -translate-y-1/2"
                aria-hidden="true"
              />
              <DoorOpen class="size-3.5 shrink-0" />
              <span class="text-sm">{{ unitLabel(uid) }}</span>
            </li>
            <li v-if="(node.units?.length ?? 0) > MAX_UNITS" class="relative flex items-center gap-2 py-0.5 text-sm">
              <span
                class="bg-border absolute top-1/2 -left-4 h-px w-3 -translate-y-1/2"
                aria-hidden="true"
              />
              ...
            </li>
          </template>
        </ul>
      </CollapsibleContent>
    </Collapsible>
  </li>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Building2, ChevronRight, DoorOpen, Layers } from 'lucide-vue-next'
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible'
import {
  displayTreeChildren,
  type StructureTreeNode,
} from '@/lib/property_setup/structurePreview'

const props = defineProps<{
  node: StructureTreeNode
}>()

const MAX_UNITS = 4

const open = ref(true)
const hasChildren = computed(() => (props.node.children?.length ?? 0) > 0)
const hasUnits = computed(() => (props.node.units?.length ?? 0) > 0)
const isCollapsible = computed(() => hasChildren.value || hasUnits.value)
const visibleChildren = computed(() => displayTreeChildren(props.node.children))
const visibleUnits = computed(() => (props.node.units ?? []).slice(0, MAX_UNITS))

// Step 3 automatic mode injects projected identifier strings; the persisted
// backend tree (step 2/4 and step 3 manual mode) carries real unit rows.
function unitLabel(unit: string | { identifier: string; display_name?: string | null }): string {
  if (typeof unit === 'string') return unit
  return unit.display_name || unit.identifier
}
</script>
