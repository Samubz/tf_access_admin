<template>
  <Card class="flex max-h-[calc(100vh-12rem)] flex-col">
    <CardHeader class="shrink-0 space-y-1 pb-3">
      <CardTitle class="text-base">{{ t('admin.property_setup.step2.preview.title') }}</CardTitle>
      <p class="text-muted-foreground text-xs">{{ t('admin.property_setup.step2.preview.subtitle') }}</p>
    </CardHeader>

    <CardContent class="flex min-h-0 flex-1 flex-col gap-4 text-sm">
      <Card class="flex min-h-0 flex-1 flex-col border bg-background shadow-none">
        <CardContent class="min-h-0 flex-1 overflow-y-auto p-3">
          <ul v-if="tree.length" class="space-y-2">
            <StructurePreviewTreeNode
              v-for="node in tree"
              :key="node.id"
              :node="node"
            />
          </ul>
          <p v-else class="text-muted-foreground">{{ placeholder }}</p>
        </CardContent>
      </Card>

      <Alert
        v-if="showAutoUpdateNote"
        class="shrink-0 border-muted bg-muted/30 text-muted-foreground [&>svg]:text-muted-foreground"
      >
        <Info class="size-4" />
        <AlertDescription>{{ t('admin.property_setup.step2.preview.auto_update') }}</AlertDescription>
      </Alert>

      <div v-if="showStats" class="grid shrink-0 grid-cols-1 gap-2 border-t pt-3">
        <div
          v-for="stat in statCards"
          :key="stat.key"
          class="flex flex-col items-center gap-1 rounded-lg border bg-muted/30 px-2 py-2.5 text-center"
        >
          <component :is="stat.icon" class="text-primary size-4" />
          <p class="text-base leading-none font-semibold">{{ stat.value }}</p>
          <p class="text-muted-foreground text-[11px] leading-tight">{{ stat.label }}</p>
        </div>
      </div>
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { DoorOpen, Info } from 'lucide-vue-next'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import StructurePreviewTreeNode from '@/components/admin/property_setup/StructurePreviewTreeNode.vue'
import {
  buildTreeFromPreviewNodes,
  type PreviewNode,
  type StructureTreeNode,
} from '@/lib/property_setup/structurePreview'

type QuickPreview = {
  nodes: PreviewNode[]
  counts: { level_1: number; level_2: number; sections: number }
}

const props = defineProps<{
  preview: Record<string, any>
  structureMode?: string
  /** Step 2: client preview built from quick-structure form (backend flat nodes). */
  quickPreview?: QuickPreview
  /** Step 3: section tree with projected units already injected into leaf nodes. */
  treeWithUnits?: StructureTreeNode[]
  // When provided, a units total is shown below the tree (step 3). Omitted in
  // step 2, where the panel shows only the section hierarchy.
  unitsCount?: number | null
}>()

const { t } = useI18n()

const isQuickMode = computed(() => props.structureMode === 'quick')

const tree = computed(() => {
  if (props.treeWithUnits) {
    return props.treeWithUnits
  }

  if (isQuickMode.value && props.quickPreview) {
    return buildTreeFromPreviewNodes(props.quickPreview.nodes)
  }

  return props.preview?.structure?.tree ?? []
})

// The numeric stat refers to the property's units, shown only when a units
// total is provided (step 3). Step 2 shows just the section hierarchy.
const showStats = computed(() => props.unitsCount != null)

const showAutoUpdateNote = computed(
  () => props.structureMode === 'manual' || props.structureMode === 'quick',
)

const statCards = computed(() => [
  {
    key: 'units',
    icon: DoorOpen,
    value: props.unitsCount ?? 0,
    label: t('admin.property_setup.step2.preview.stats.units'),
  },
])

const placeholder = computed(() => {
  if (props.structureMode === 'none') {
    return t('admin.property_setup.step2.preview.none')
  }

  return t('admin.property_setup.step2.preview.placeholder')
})
</script>
