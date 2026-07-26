<template>
  <div>
    <Header :itemsBreadcrumb="itemsBreadcrumb" :title="t('admin.people.edit.title')" />
    <Form
      ref="formRef"
      :description="t('admin.people.edit.description')"
      :submitLabel="t('admin.people.edit.submit')"
      :roles="props.roles"
      :person-types="props.person_types"
      :statuses="props.statuses"
      :server-errors="props.errors"
      :default-values="props.person"
      :cancel-label="t('common.back')"
      @submit="onSubmit"
    />
  </div>
</template>

<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import Form from '@/components/admin/person/Form.vue'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import type { PersonSchema } from '@/lib/schemas/person'
import { ref, computed } from 'vue'
import type { Person } from '@/types/person'
import { admin_person_path } from '@/routes'
import Header from '@/components/admin/layout/Header.vue'
import { getPeopleBreadcrumbs } from '@/lib/breadcrumbs/person'
import { applyErrorsToFormRef } from '@/lib/composables/forms/apply_errors_to_form_ref'

const { t } = useI18n()

const props = defineProps<{
  person: Person
  roles: string[]
  person_types: string[]
  statuses: string[]
  errors?: Record<string, string[]>
}>()

const formRef = ref<InstanceType<typeof Form> | null>(null)
const itemsBreadcrumb = computed(() => getPeopleBreadcrumbs(t))

function onSubmit(data: PersonSchema) {
  router.put(admin_person_path(props.person.id as string), {
    person: {
      first_name: data.first_name,
      last_name: data.last_name,
      document_number: data.document_number,
      email: data.email,
      phone: data.phone,
      birthdate: data.birthdate,
    },
  }, {
    preserveScroll: true,
    preserveState: true,
    onSuccess: () => toast.success(t('admin.people.updated_successfully')),
    onError: (errors) => {
      toast.error(t('admin.people.update_failed'))
      applyErrorsToFormRef(formRef, errors)
    },
  })
}
</script>
