<template>
  <div class="grid gap-4 lg:grid-cols-2">
    <Card>
      <CardHeader>
        <CardTitle>{{ t('admin.people.profile.summary.personal_info') }}</CardTitle>
      </CardHeader>
      <CardContent>
        <dl class="grid gap-3 text-sm">
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.display_name.label') }}</dt>
            <dd>{{ person.display_name }}</dd>
          </div>
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.first_name.label') }}</dt>
            <dd>{{ person.first_name || '—' }}</dd>
          </div>
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.last_name.label') }}</dt>
            <dd>{{ person.last_name || '—' }}</dd>
          </div>
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.document_number.label') }}</dt>
            <dd>{{ documentLabel }}</dd>
          </div>
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.person_type.label') }}</dt>
            <dd>{{ t(`admin.people.person_types.${person.person_type}`) }}</dd>
          </div>
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.status.label') }}</dt>
            <dd>{{ t(`admin.people.statuses.${person.status}`) }}</dd>
          </div>
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.birthdate.label') }}</dt>
            <dd>{{ birthdateLabel }}</dd>
          </div>
        </dl>
      </CardContent>
    </Card>

    <Card>
      <CardHeader>
        <CardTitle>{{ t('admin.people.profile.summary.linked_user') }}</CardTitle>
      </CardHeader>
      <CardContent>
        <dl v-if="person.user_id" class="grid gap-3 text-sm">
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.profile.summary.user_name') }}</dt>
            <dd>{{ person.user_name || '—' }}</dd>
          </div>
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.profile.summary.user_email') }}</dt>
            <dd>{{ person.user_email || '—' }}</dd>
          </div>
        </dl>
        <p v-else class="text-sm text-muted-foreground">
          {{ t('admin.people.profile.summary.no_linked_user') }}
        </p>
      </CardContent>
    </Card>

    <Card>
      <CardHeader>
        <CardTitle>{{ t('admin.people.profile.summary.contextual_roles') }}</CardTitle>
      </CardHeader>
      <CardContent>
        <div v-if="contextualRoles.length > 0" class="flex flex-wrap gap-2">
          <Badge
            v-for="role in contextualRoles"
            :key="role"
            variant="secondary"
          >
            {{ contextualRoleLabel(role) }}
          </Badge>
        </div>
        <p v-else class="text-sm text-muted-foreground">
          {{ t('admin.people.profile.summary.no_contextual_roles') }}
        </p>
      </CardContent>
    </Card>

    <Card>
      <CardHeader>
        <CardTitle>{{ t('admin.people.profile.summary.tenant_access') }}</CardTitle>
      </CardHeader>
      <CardContent>
        <dl class="grid gap-3 text-sm">
          <div class="grid grid-cols-[minmax(0,9rem)_1fr] gap-2">
            <dt class="text-muted-foreground">{{ t('admin.people.input.role.label') }}</dt>
            <dd>{{ tenantRoleLabel }}</dd>
          </div>
        </dl>
      </CardContent>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { Person } from '@/types/person'
import type { PersonContextualRole } from '@/types/person_profile'

const props = defineProps<{
  person: Person
  contextualRoles: PersonContextualRole[]
}>()

const { t, locale } = useI18n()

const documentLabel = computed(() => {
  if (!props.person.document_number) return '—'

  const type = props.person.document_type ? `${props.person.document_type} ` : ''
  return `${type}${props.person.document_number}`.trim()
})

const birthdateLabel = computed(() => {
  if (!props.person.birthdate) return '—'

  const date = new Date(props.person.birthdate)
  if (Number.isNaN(date.getTime())) return props.person.birthdate

  return new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium' }).format(date)
})

const tenantRoleLabel = computed(() => {
  const role = props.person.tenant_role || props.person.role
  if (!role) return t('no_role')

  return t(`roles.${role}`)
})

function contextualRoleLabel(role: PersonContextualRole) {
  return t(`admin.people.profile.contextual_roles.${role}`)
}
</script>
