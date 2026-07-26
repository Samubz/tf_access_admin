<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div class="flex items-start gap-4">
        <Avatar class="size-14">
          <AvatarFallback class="text-lg">{{ initials }}</AvatarFallback>
        </Avatar>
        <div class="space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="text-2xl font-bold tracking-tight sm:text-3xl">{{ person.display_name }}</h1>
            <StatusDotBadge
              :label="statusLabel"
              :tone="person.status === 'active' ? 'success' : 'muted'"
            />
          </div>
          <div class="flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted-foreground">
            <span v-if="documentLabel">
              {{ t('admin.people.profile.header.document') }}: {{ documentLabel }}
            </span>
            <span>
              {{ t('admin.people.profile.header.email') }}: {{ person.email || '—' }}
            </span>
            <span>
              {{ t('admin.people.profile.header.phone') }}: {{ person.phone || '—' }}
            </span>
          </div>
          <div v-if="contextualRoles.length > 0" class="flex flex-wrap gap-2">
            <Badge
              v-for="role in contextualRoles"
              :key="role"
              variant="outline"
            >
              {{ contextualRoleLabel(role) }}
            </Badge>
          </div>
        </div>
      </div>
      <div v-if="permissions.edit" class="shrink-0">
        <Button variant="outline" as-child>
          <Link :href="edit_admin_person_path(person.id as string)">
            <Pencil class="size-4" />
            {{ t('admin.people.profile.header.edit') }}
          </Link>
        </Button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { Pencil } from 'lucide-vue-next'
import StatusDotBadge from '@/components/admin/shared/StatusDotBadge.vue'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { personInitials } from '@/lib/utils/unit'
import { edit_admin_person_path } from '@/routes'
import type { Person } from '@/types/person'
import type { PersonContextualRole, PersonProfilePermissions } from '@/types/person_profile'

const props = defineProps<{
  person: Person
  contextualRoles: PersonContextualRole[]
  permissions: PersonProfilePermissions
}>()

const { t } = useI18n()

const initials = computed(() => personInitials(props.person.display_name))

const statusLabel = computed(() =>
  t(`admin.people.statuses.${props.person.status}`),
)

const documentLabel = computed(() => {
  if (!props.person.document_number) return null

  const type = props.person.document_type ? `${props.person.document_type} ` : ''
  return `${type}${props.person.document_number}`.trim()
})

function contextualRoleLabel(role: PersonContextualRole) {
  return t(`admin.people.profile.contextual_roles.${role}`)
}
</script>
