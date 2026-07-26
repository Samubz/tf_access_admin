<template>
  <Card class="w-full">
    <CardHeader>
      <CardTitle v-if="props.title">{{ props.title }}</CardTitle>
      <CardDescription>
        {{ props.description }}
      </CardDescription>
    </CardHeader>
    <CardContent>
      <form id="form-person" @submit="onSubmit">
        <FieldGroup class="flex flex-col md:flex-row">
          <VeeField v-slot="{ field, errors }" name="first_name">
            <Field :data-invalid="!!errors.length">
              <FieldLabel for="form-person-first-name">
                {{ t('admin.people.input.first_name.label') }}
              </FieldLabel>
              <Input
                id="form-person-first-name"
                v-bind="field"
                :placeholder="t('admin.people.input.first_name.placeholder')"
                autocomplete="off"
                :aria-invalid="!!errors.length"
              />
              <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
            </Field>
          </VeeField>
          <VeeField v-slot="{ field, errors }" name="last_name">
            <Field :data-invalid="!!errors.length">
              <FieldLabel for="form-person-last-name">
                {{ t('admin.people.input.last_name.label') }}
              </FieldLabel>
              <Input
                id="form-person-last-name"
                v-bind="field"
                :placeholder="t('admin.people.input.last_name.placeholder')"
                autocomplete="off"
                :aria-invalid="!!errors.length"
              />
              <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
            </Field>
          </VeeField>
        </FieldGroup>
        <FieldGroup class="mt-4 flex flex-col md:flex-row">
          <VeeField v-slot="{ field, errors }" name="document_number">
            <Field :data-invalid="!!errors.length">
              <FieldLabel for="form-person-document-number">
                {{ t('admin.people.input.document_number.label') }}
              </FieldLabel>
              <Input
                id="form-person-document-number"
                v-bind="field"
                :placeholder="t('admin.people.input.document_number.placeholder')"
                autocomplete="off"
                :aria-invalid="!!errors.length"
              />
              <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
            </Field>
          </VeeField>
          <VeeField v-slot="{ field, errors }" name="phone">
            <Field :data-invalid="!!errors.length">
              <FieldLabel for="form-person-phone">
                {{ t('admin.people.input.phone.label') }}
              </FieldLabel>
              <Input
                id="form-person-phone"
                v-bind="field"
                :placeholder="t('admin.people.input.phone.placeholder')"
                autocomplete="off"
                :aria-invalid="!!errors.length"
              />
              <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
            </Field>
          </VeeField>
        </FieldGroup>
        <FieldGroup class="mt-4 flex flex-col md:flex-row">
          <VeeField v-slot="{ field, errors }" name="email">
            <Field :data-invalid="!!errors.length">
              <FieldLabel for="form-person-email">
                {{ t('admin.people.input.email.label') }}
              </FieldLabel>
              <Input
                id="form-person-email"
                v-bind="field"
                type="email"
                :placeholder="t('admin.people.input.email.placeholder')"
                autocomplete="off"
                :aria-invalid="!!errors.length"
              />
              <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
            </Field>
          </VeeField>
          <VeeField v-slot="{ value, handleChange, errors }" name="birthdate">
            <Field :data-invalid="!!errors.length">
              <FieldLabel for="form-person-birthdate">
                {{ t('admin.people.input.birthdate.label') }}
              </FieldLabel>
              <DatePicker
                id="form-person-birthdate"
                :model-value="value"
                :placeholder="t('admin.people.input.birthdate.placeholder')"
                :aria-invalid="!!errors.length"
                @update:model-value="handleChange"
              />
              <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
            </Field>
          </VeeField>
        </FieldGroup>
        <FieldGroup v-if="!props.defaultValues" class="mt-4">
          <VeeField v-slot="{ value, handleChange }" name="send_invitation" type="checkbox">
            <label class="flex cursor-pointer items-start gap-3">
              <Checkbox :model-value="value" @update:model-value="handleChange" />
              <span class="text-sm leading-snug">{{ t('admin.people.input.send_invitation.label') }}</span>
            </label>
          </VeeField>
        </FieldGroup>
      </form>
    </CardContent>
    <CardFooter>
      <Field orientation="horizontal" class="md:flex md:justify-end flex-col md:flex-row">
        <Button type="button" as="a" :href="admin_people_path()" variant="outline" class="w-full md:w-auto">
          {{ props.cancelLabel || t('common.back') }}
        </Button>
        <Button type="submit" form="form-person" class="w-full md:w-auto">
          {{ props.submitLabel }}
        </Button>
      </Field>
    </CardFooter>
  </Card>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { toTypedSchema } from '@vee-validate/zod'
import { useForm, Field as VeeField } from 'vee-validate'
import { useI18n } from 'vue-i18n'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { DatePicker } from '@/components/ui/datepicker'
import { personSchema, type PersonSchema } from '@/lib/schemas/person'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { useServerFormErrors } from '@/lib/composables/forms/useServerFormErrors'
import { admin_people_path } from '@/routes'
import type { Person } from '@/types/person'

const props = defineProps<{
  description: string
  submitLabel: string
  title?: string
  cancelLabel?: string
  defaultValues?: Person
  serverErrors?: Record<string, string[]>
}>()

const emit = defineEmits<{
  (e: 'submit', data: PersonSchema): void
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const formSchema = toTypedSchema(personSchema)

const { handleSubmit, setErrors, setValues } = useForm({
  validationSchema: formSchema,
  initialValues: {
    first_name: '',
    last_name: '',
    document_number: '',
    email: '',
    phone: '',
    birthdate: '',
    send_invitation: false,
  },
})

onMounted(() => {
  if (props.defaultValues) {
    setValues({
      first_name: props.defaultValues.first_name ?? '',
      last_name: props.defaultValues.last_name ?? '',
      document_number: props.defaultValues.document_number ?? '',
      email: props.defaultValues.email ?? '',
      phone: props.defaultValues.phone ?? '',
      birthdate: props.defaultValues.birthdate ?? '',
    })
  }
})

const { applyServerErrors } = useServerFormErrors(setErrors)

const onSubmit = handleSubmit((data) => {
  emit('submit', data)
})

defineExpose({ applyServerErrors })
</script>
