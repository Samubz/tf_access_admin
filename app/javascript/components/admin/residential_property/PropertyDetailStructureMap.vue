<template>
  <Card class="shadow-none">
    <CardHeader>
      <CardTitle class="text-base">{{ t('admin.residential_properties.show.structure.title') }}</CardTitle>
    </CardHeader>
    <CardContent>
      <ul class="space-y-0.5">
        <li v-for="section in tree" :key="section.id">
          <PropertyDetailSectionRow :section="section" :property-id="propertyId" :can-manage-unit="canManageUnit" />
        </li>
      </ul>
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import PropertyDetailSectionRow, {
  type DetailSectionNode,
} from '@/components/admin/residential_property/PropertyDetailSectionRow.vue'

defineProps<{
  tree: DetailSectionNode[]
  propertyId: string
  canManageUnit: boolean
}>()

const { t } = useI18n()
</script>
