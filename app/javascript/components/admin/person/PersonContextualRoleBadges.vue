<template>
  <div v-if="roles.length > 0" class="flex flex-wrap gap-1">
    <Badge
      v-for="role in roles"
      :key="role"
      variant="outline"
      class="text-xs font-normal"
    >
      {{ t(`admin.people.profile.contextual_roles.${role}`) }}
    </Badge>
  </div>
  <span v-else class="text-sm text-muted-foreground">—</span>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Badge } from '@/components/ui/badge'
import type { PersonContextualRole } from '@/types/person_profile'

defineProps<{
  roles: PersonContextualRole[]
}>()

const { t } = useI18n()
</script>
