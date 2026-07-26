<template>
  <Card class="border-primary/20 bg-primary/5">
    <CardHeader class="pb-3">
      <CardTitle class="flex items-center gap-2 text-base">
        <Info class="size-4 text-primary" />
        {{ t('admin.property_setup.step5.consequences.title') }}
      </CardTitle>
    </CardHeader>
    <CardContent class="space-y-3 text-sm">
      <ul class="space-y-2">
        <li v-for="item in items" :key="item.key" class="flex items-start gap-2">
          <component :is="item.icon" class="text-primary mt-0.5 size-4 shrink-0" />
          <span>{{ item.label }}</span>
        </li>
      </ul>
      <p class="text-muted-foreground flex items-start gap-2 border-t pt-3 text-xs">
        <Clock class="mt-0.5 size-3.5 shrink-0" />
        {{ t('admin.property_setup.step5.consequences.duration_note') }}
      </p>
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, Clock, DoorOpen, Info, Layers, Pencil } from 'lucide-vue-next'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

const props = defineProps<{
  preview: Record<string, any>
}>()

const { t } = useI18n()

const unitCount = computed(() => props.preview?.counts?.units ?? props.preview?.total_units ?? 0)

const items = computed(() => [
  {
    key: 'property',
    icon: Building2,
    label: t('admin.property_setup.step5.consequences.create_property'),
  },
  {
    key: 'structure',
    icon: Layers,
    label: t('admin.property_setup.step5.consequences.create_structure'),
  },
  {
    key: 'units',
    icon: DoorOpen,
    label: t('admin.property_setup.step5.consequences.create_units', { count: unitCount.value }),
  },
  {
    key: 'edit',
    icon: Pencil,
    label: t('admin.property_setup.step5.consequences.edit_after'),
  },
])
</script>
