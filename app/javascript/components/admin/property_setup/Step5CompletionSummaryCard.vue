<template>
  <Card class="border bg-background shadow-none">
    <CardHeader class="pb-2">
      <CardTitle class="text-sm">{{ t('admin.property_setup.step5.final_summary.title') }}</CardTitle>
    </CardHeader>
    <CardContent class="space-y-2">
      <div
        v-for="item in items"
        :key="item.key"
        class="flex items-center gap-2 text-sm"
      >
        <CheckCircle2 class="size-4 shrink-0 text-green-600" />
        <span>{{ item.label }}</span>
      </div>
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { CheckCircle2 } from 'lucide-vue-next'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

defineProps<{
  items: Array<{ key: string; label: string }>
}>()

const { t } = useI18n()
</script>
