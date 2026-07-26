<template>
  <Card>
    <CardHeader class="pb-4">
      <CardTitle class="flex items-center gap-2 text-base">
        <span class="bg-primary/10 text-primary inline-flex size-8 items-center justify-center rounded-full">
          <Building2 class="size-4" />
        </span>
        {{ t('admin.property_setup.step1.summary.title') }}
      </CardTitle>
    </CardHeader>
    <CardContent class="space-y-4">
      <div class="space-y-4">
        <div class="flex items-start gap-3">
          <Building2 class="text-muted-foreground mt-0.5 size-4 shrink-0" />
          <div class="min-w-0">
            <p class="text-muted-foreground text-xs">{{ t('admin.property_setup.step1.summary.type') }}</p>
            <p class="text-sm font-medium">{{ propertyTypeLabel }}</p>
          </div>
        </div>

        <div class="flex items-start gap-3">
          <MapPin class="text-muted-foreground mt-0.5 size-4 shrink-0" />
          <div class="min-w-0">
            <p class="text-muted-foreground text-xs">{{ t('admin.property_setup.step1.summary.location') }}</p>
            <p class="text-sm font-medium">{{ locationLabel }}</p>
          </div>
        </div>

      </div>

      <div class="border-t pt-4">
        <div class="flex items-start gap-3">
          <Clock class="text-muted-foreground mt-0.5 size-4 shrink-0" />
          <div class="min-w-0 space-y-1.5">
            <p class="text-muted-foreground text-xs">{{ t('admin.property_setup.step1.summary.flow_status') }}</p>
            <Badge class="border-transparent bg-orange-100 font-normal text-orange-800 hover:bg-orange-100">
              {{ t('admin.property_setup.step1.summary.flow_status_pending') }}
            </Badge>
          </div>
        </div>
      </div>
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, Clock, MapPin } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

const props = defineProps<{
  values: Record<string, unknown>
}>()

const { t } = useI18n()

const propertyTypeLabel = computed(() => {
  const type = props.values.property_type as string | undefined
  if (!type) return '—'
  return t(`admin.residential_properties.property_types.${type}`)
})

const locationLabel = computed(() => {
  const city = props.values.city as string | undefined
  return city?.trim() || '—'
})

</script>
