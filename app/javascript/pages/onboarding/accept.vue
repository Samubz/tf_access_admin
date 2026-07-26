<template>
  <div class="flex min-h-screen items-center justify-center px-4 py-12">
    <Card class="w-full max-w-md">
      <CardHeader>
        <CardTitle>{{ t('onboarding.accept.title') }}</CardTitle>
        <CardDescription>
          {{ t('onboarding.accept.subtitle', { organization: props.organization_name }) }}
        </CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <p v-if="props.email" class="text-sm text-muted-foreground">
          {{ t('onboarding.accept.email_label') }}: <span class="font-medium">{{ props.email }}</span>
        </p>

        <p class="text-sm text-muted-foreground">
          {{ props.needs_account ? t('onboarding.accept.needs_account_description') : t('onboarding.accept.no_account_description') }}
        </p>

        <form v-if="props.needs_account" id="form-onboarding-accept" class="space-y-4" @submit="onSubmit">
          <FieldGroup>
            <VeeField v-slot="{ field, errors }" name="name">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="onboarding-accept-name">{{ t('onboarding.accept.input.name.label') }}</FieldLabel>
                <Input
                  id="onboarding-accept-name"
                  v-bind="field"
                  :placeholder="t('onboarding.accept.input.name.placeholder')"
                  autocomplete="name"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
            <VeeField v-slot="{ field, errors }" name="dni">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="onboarding-accept-dni">{{ t('onboarding.accept.input.dni.label') }}</FieldLabel>
                <Input
                  id="onboarding-accept-dni"
                  v-bind="field"
                  :placeholder="t('onboarding.accept.input.dni.placeholder')"
                  autocomplete="off"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
            <VeeField v-slot="{ field, errors }" name="password">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="onboarding-accept-password">{{ t('onboarding.accept.input.password.label') }}</FieldLabel>
                <Input
                  id="onboarding-accept-password"
                  v-bind="field"
                  type="password"
                  :placeholder="t('onboarding.accept.input.password.placeholder')"
                  autocomplete="new-password"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
            <VeeField v-slot="{ field, errors }" name="password_confirmation">
              <Field :data-invalid="!!errors.length">
                <FieldLabel for="onboarding-accept-password-confirmation">
                  {{ t('onboarding.accept.input.password_confirmation.label') }}
                </FieldLabel>
                <Input
                  id="onboarding-accept-password-confirmation"
                  v-bind="field"
                  type="password"
                  :placeholder="t('onboarding.accept.input.password_confirmation.placeholder')"
                  autocomplete="new-password"
                  :aria-invalid="!!errors.length"
                />
                <FieldError v-if="errors.length" :errors="translateErrors(errors)" />
              </Field>
            </VeeField>
          </FieldGroup>
        </form>
      </CardContent>
      <CardFooter class="flex flex-col gap-2">
        <Button v-if="props.needs_account" type="submit" form="form-onboarding-accept" class="w-full" :disabled="isSubmitting">
          {{ t('onboarding.accept.submit') }}
        </Button>
        <Button v-else class="w-full" :disabled="isSubmitting" @click="acceptExistingAccount">
          {{ t('onboarding.accept.submit') }}
        </Button>
      </CardFooter>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { toTypedSchema } from '@vee-validate/zod'
import { useForm, Field as VeeField } from 'vee-validate'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { onboardingAcceptanceSchema, type OnboardingAcceptanceSchema } from '@/lib/schemas/onboarding_acceptance'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { useServerFormErrors } from '@/lib/composables/forms/useServerFormErrors'
import { onboarding_acceptance_path } from '@/routes'

const props = defineProps<{
  token: string
  organization_name: string
  needs_account: boolean
  email: string | null
  errors?: Record<string, string[]>
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const isSubmitting = ref(false)

const formSchema = toTypedSchema(onboardingAcceptanceSchema)
const { handleSubmit, setErrors } = useForm({
  validationSchema: formSchema,
  initialValues: { name: '', dni: '', password: '', password_confirmation: '' },
})
const { applyServerErrors } = useServerFormErrors(setErrors)

if (props.errors) applyServerErrors(props.errors)

onMounted(() => {
  // The controller redirects back to this page with a shared `base` error
  // (e.g. AcceptInvitation::AccountRequired/RecordInvalid) rather than a
  // validation re-render, so router.post's onError never fires for it — this
  // is the only place that surfaces it. The message is a raw server string,
  // not an i18n key, so it is not passed through t().
  const baseError = props.errors?.base?.[0]
  if (baseError) toast.error(baseError)
})

function submitAcceptance(payload: Record<string, string>) {
  isSubmitting.value = true
  router.post(onboarding_acceptance_path(props.token), payload, {
    preserveScroll: true,
    onError: () => {
      toast.error(t('onboarding.accept.errors.accept_failed'))
    },
    onFinish: () => {
      isSubmitting.value = false
    },
  })
}

const onSubmit = handleSubmit((data: OnboardingAcceptanceSchema) => {
  submitAcceptance({
    name: data.name ?? '',
    dni: data.dni ?? '',
    password: data.password,
    password_confirmation: data.password_confirmation,
  })
})

function acceptExistingAccount() {
  submitAcceptance({})
}
</script>
