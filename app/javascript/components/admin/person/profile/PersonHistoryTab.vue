<template>
  <Card>
    <CardHeader>
      <CardTitle>{{ t('admin.people.profile.history.title') }}</CardTitle>
      <CardDescription>{{ t('admin.people.profile.history.description') }}</CardDescription>
    </CardHeader>
    <CardContent>
      <Timeline
        :entries="entries"
        :empty-title="t('admin.people.profile.history.empty')"
        :locale="locale"
      />
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import Timeline from '@/components/admin/shared/Timeline.vue'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import type { PersonChangeHistoryEntry } from '@/types/person_profile'

const props = defineProps<{
  changeHistory: PersonChangeHistoryEntry[]
}>()

const { t, locale } = useI18n()

const entries = computed(() =>
  props.changeHistory.map((entry) => ({
    id: entry.id,
    occurred_at: entry.occurred_at,
    description: entry.description,
    actor_name: entry.actor_name,
    tone: entry.tone,
  })),
)
</script>
