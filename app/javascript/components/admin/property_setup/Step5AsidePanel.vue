<template>
  <Step5ConsequencesPanel v-if="!confirmed" :preview="preview" />
  <Card v-else class="border bg-muted/20 shadow-none">
    <CardHeader class="pb-3">
      <CardTitle class="text-sm">{{ t('admin.property_setup.step5.completed.whats_next.title') }}</CardTitle>
    </CardHeader>
    <CardContent class="space-y-4">
      <ul class="space-y-4">
        <li v-for="item in whatsNextItems" :key="item.key" class="flex items-start gap-3">
          <span class="bg-background inline-flex size-8 shrink-0 items-center justify-center rounded-full border">
            <component :is="item.icon" class="size-4 text-green-600" />
          </span>
          <div class="min-w-0 space-y-0.5">
            <p class="text-sm font-medium">{{ item.title }}</p>
            <p class="text-muted-foreground text-xs leading-relaxed">{{ item.description }}</p>
          </div>
        </li>
      </ul>
      <Step5CompletionSummaryCard :items="completionChecklist" />
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { DoorOpen, Layers, UserRound, Users } from 'lucide-vue-next'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import Step5ConsequencesPanel from '@/components/admin/property_setup/Step5ConsequencesPanel.vue'
import Step5CompletionSummaryCard from '@/components/admin/property_setup/Step5CompletionSummaryCard.vue'

const props = defineProps<{
  preview: Record<string, any>
  confirmed: boolean
}>()

const { t } = useI18n()

const structureMode = computed(() => props.preview?.structure?.mode)

const completionChecklist = computed(() => {
  const items = [
    {
      key: 'property',
      label: t('admin.property_setup.step5.completed.checklist.property_created'),
    },
  ]

  if (structureMode.value !== 'none') {
    items.push({
      key: 'structure',
      label: t('admin.property_setup.step5.completed.checklist.structure_created'),
    })
  }

  items.push({
    key: 'units',
    label: t('admin.property_setup.step5.completed.checklist.units_generated'),
  })

  return items
})

const whatsNextItems = computed(() => [
  {
    key: 'structure',
    icon: Layers,
    title: t('admin.property_setup.step5.completed.whats_next.review_structure.title'),
    description: t('admin.property_setup.step5.completed.whats_next.review_structure.description'),
  },
  {
    key: 'units',
    icon: DoorOpen,
    title: t('admin.property_setup.step5.completed.whats_next.manage_units.title'),
    description: t('admin.property_setup.step5.completed.whats_next.manage_units.description'),
  },
  {
    key: 'owners',
    icon: Users,
    title: t('admin.property_setup.step5.completed.whats_next.load_owners.title'),
    description: t('admin.property_setup.step5.completed.whats_next.load_owners.description'),
  },
  {
    key: 'residents',
    icon: UserRound,
    title: t('admin.property_setup.step5.completed.whats_next.configure_residents.title'),
    description: t('admin.property_setup.step5.completed.whats_next.configure_residents.description'),
  },
])
</script>
