<template>
  <UnitPlaceholderTab
    :title="t('admin.visits.show.documents.title')"
    :description="t('admin.visits.show.documents.description')"
  />
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import UnitPlaceholderTab from '@/components/admin/unit/UnitPlaceholderTab.vue'

const { t } = useI18n()
</script>
