<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <Header :items-breadcrumb="breadcrumbs" :title="t('admin.property_setup.wizard.title')" />
      <p class="text-muted-foreground text-sm">{{ t('admin.property_setup.wizard.description') }}</p>
    </div>

    <WizardStepper :current-step="currentStep" :completed-through="completedThrough" />

    <div :class="showAside ? 'grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]' : ''">
      <Card>
        <CardHeader v-if="!(currentStep === 5 && isCompleted)" class="pb-4">
          <CardTitle>{{ stepTitle }}</CardTitle>
        </CardHeader>
        <CardHeader v-else class="space-y-1 pb-4">
          <CardTitle>{{ stepTitle }}</CardTitle>
          <p class="text-muted-foreground text-sm font-normal">
            {{ t('admin.property_setup.step5.completed.subtitle') }}
          </p>
        </CardHeader>
        <CardContent>
          <Step1Property
            v-if="currentStep === 1"
            ref="step1Ref"
            :property-types="propertyTypes"
            :initial-values="step1Values"
            :errors="formErrors"
          />
          <template v-else-if="currentStep === 2">
            <Alert
              v-if="wizardState.property_type_changed"
              class="mb-4 border-amber-200 bg-amber-50 text-amber-900 [&>svg]:text-amber-700"
            >
              <Info class="size-4" />
              <AlertDescription>{{ t('admin.property_setup.step2.property_type_changed_notice') }}</AlertDescription>
            </Alert>
            <Step2Structure
              ref="step2Ref"
              :property-id="propertyId"
              :wizard="wizardState"
              :section-types="sectionTypes"
              :preview="preview"
              :structure-format="structureFormat"
              :property-type="step2PropertyType"
              :manual-only="manualOnly"
            />
          </template>
          <Step3Units
            v-else-if="currentStep === 3"
            ref="step3Ref"
            :property="property"
            :wizard="wizardState"
            :unit-types="unitTypes"
            :preview="preview"
            :errors="formErrors"
            :structure-mode="step3StructureMode"
            :units-in="props.units_in"
            :manual-only="manualOnly"
          />
          <Step4Summary v-else-if="currentStep === 4" :preview="preview" />
          <Step5Confirm
            v-else
            :preview="preview"
            :confirmed="isCompleted"
            :next-actions="nextActions"
            :property-id="propertyId"
            :requires-acknowledgement="canOfferConfigured"
            v-model:acknowledged="acknowledged"
          />

          <div v-if="currentStep === 4" class="mt-6">
            <Alert
              class="border-amber-200 bg-amber-50 text-amber-900 [&>svg]:text-amber-700"
            >
              <Info class="size-4" />
              <AlertDescription>{{ t('admin.property_setup.step4.notice') }}</AlertDescription>
            </Alert>
          </div>
        </CardContent>
        <CardFooter class="flex flex-wrap items-center justify-between gap-3 border-t pt-6">
          <div class="min-w-0 flex-1">
            <Button
              v-if="currentStep === 5 && isCompleted"
              variant="outline"
              :disabled="submitting"
              @click="goBack"
            >
              <ArrowLeft class="mr-2 size-4" />
              {{ t('admin.property_setup.step5.completed.footer.back_to_summary') }}
            </Button>
            <Button
              v-else-if="currentStep > 1"
              variant="outline"
              :disabled="submitting"
              @click="goBack"
            >
              {{ t('admin.property_setup.wizard.actions.back') }}
            </Button>
            <div v-else />
          </div>
          <div class="flex flex-wrap gap-2">
            <template v-if="currentStep === 5 && isCompleted">
              <Button variant="outline" :disabled="submitting" @click="onClose">
                {{ t('admin.property_setup.step5.completed.footer.close') }}
              </Button>
              <Button
                v-if="propertyId"
                as="a"
                :href="`/admin/residential_properties/${propertyId}/edit`"
              >
                {{ t('admin.property_setup.step5.completed.footer.go_to_property') }}
                <ArrowRight class="ml-2 size-4" />
              </Button>
            </template>
            <template v-else>
              <Button variant="ghost" :disabled="submitting" @click="onCancel">
                {{ t('admin.property_setup.wizard.actions.cancel') }}
              </Button>
              <Button
                v-if="currentStep < 5"
                :disabled="submitting"
                @click="onContinue"
              >
                {{ continueLabel }}
              </Button>
              <template v-else-if="!isCompleted && canOfferConfigured">
                <Button variant="outline" :disabled="submitting" @click="onSaveCreated">
                  {{ t('admin.property_setup.wizard.actions.save_created') }}
                </Button>
                <Button :disabled="submitting || !acknowledged" @click="onConfirm">
                  {{ t('admin.property_setup.wizard.actions.confirm') }}
                </Button>
              </template>
              <Button
                v-else-if="!isCompleted"
                :disabled="submitting"
                @click="onSaveExisting"
              >
                {{ t('admin.property_setup.wizard.actions.save') }}
              </Button>
            </template>
          </div>
        </CardFooter>
      </Card>

      <aside v-if="showAside" class="space-y-4">
        <InitialSummaryPanel v-if="currentStep === 1" :values="step1Preview" />
        <StructurePreviewPanel
          v-else-if="currentStep === 2"
          :preview="preview"
          :structure-mode="step2StructureMode"
          :quick-preview="step2QuickPreview"
        />
        <template v-else-if="currentStep === 3">
          <StructurePreviewPanel
            :preview="preview"
            :structure-mode="step3StructureMode"
            :tree-with-units="step3ClientPreviewTree"
            :units-count="step3UnitsCount"
          />
          <!-- <UnitsPreviewPanel
            :property-id="propertyId"
            :preview="preview"
            :generation-params="step3PreviewParams"
            :automatic-mode="step3AutomaticMode"
          /> -->
        </template>
        <StructurePreviewPanel
          v-else-if="currentStep === 4"
          :preview="preview"
          :structure-mode="step4StructureMode"
        />
        <Step5AsidePanel
          v-else-if="currentStep === 5"
          :preview="preview"
          :confirmed="isCompleted"
        />
      </aside>
    </div>

    <AlertDialog :open="showResetDialog">
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{{ t('admin.property_setup.wizard.reset_confirm.title') }}</AlertDialogTitle>
          <AlertDialogDescription>
            {{ t('admin.property_setup.wizard.reset_confirm.description') }}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel :disabled="submitting" @click="cancelReset">
            {{ t('admin.property_setup.wizard.reset_confirm.cancel') }}
          </AlertDialogCancel>
          <AlertDialogAction :disabled="submitting" @click="confirmReset">
            {{ t('admin.property_setup.wizard.reset_confirm.confirm') }}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, toValue } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { ArrowLeft, ArrowRight, Info } from 'lucide-vue-next'
import Header from '@/components/admin/layout/Header.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import WizardStepper from '@/components/admin/property_setup/WizardStepper.vue'
import Step1Property from '@/components/admin/property_setup/Step1Property.vue'
import Step2Structure from '@/components/admin/property_setup/Step2Structure.vue'
import Step3Units from '@/components/admin/property_setup/Step3Units.vue'
import Step4Summary from '@/components/admin/property_setup/Step4Summary.vue'
import Step5Confirm from '@/components/admin/property_setup/Step5Confirm.vue'
import InitialSummaryPanel from '@/components/admin/property_setup/InitialSummaryPanel.vue'
import StructurePreviewPanel from '@/components/admin/property_setup/StructurePreviewPanel.vue'
import Step5AsidePanel from '@/components/admin/property_setup/Step5AsidePanel.vue'
import type { PropertyStructureFormat } from '@/lib/property_setup/structurePreview'

const props = defineProps<{
  step: number
  completed?: boolean
  property: Record<string, unknown> | null
  wizard: Record<string, unknown>
  preview: Record<string, unknown>
  property_types: string[]
  section_types: string[]
  unit_types: string[]
  structure_format: PropertyStructureFormat | null
  units_in: string | null
  next_actions: string[]
  setup?: { manual_only: boolean; configurable: boolean }
  errors?: Record<string, string[]>
}>()

const { t } = useI18n()
const page = usePage()
const submitting = ref(false)
const acknowledged = ref(false)
const step1Ref = ref<InstanceType<typeof Step1Property> | null>(null)
const step2Ref = ref<InstanceType<typeof Step2Structure> | null>(null)
const step3Ref = ref<InstanceType<typeof Step3Units> | null>(null)

const currentStep = computed(() => props.step)
const propertyId = computed(() => props.property?.id as string | undefined)
const wizardState = computed(() => props.wizard ?? {})
const preview = computed(() => props.preview ?? {})
const propertyTypes = computed(() => props.property_types ?? [])
const sectionTypes = computed(() => props.section_types ?? [])
const unitTypes = computed(() => props.unit_types ?? [])
const nextActions = computed(() => props.next_actions ?? [])
const formErrors = computed(() => props.errors ?? (page.props.errors as Record<string, string[]> | undefined) ?? {})
const isCompleted = computed(() => props.completed === true)
const manualOnly = computed(() => props.setup?.manual_only === true)
const canOfferConfigured = computed(() => props.setup?.configurable === true)
const pendingConfirmPayload = ref<ReturnType<typeof buildPayload> | null>(null)
const showResetDialog = computed(() => Boolean(page.props.needs_confirmation) && pendingConfirmPayload.value !== null)
const completedThrough = computed(() => Math.max(0, currentStep.value - 1))

const structureFormat = computed(() => props.structure_format ?? null)
const step2PropertyType = computed(
  () => (props.property?.property_type as string) ?? (wizardState.value.property_type as string) ?? '',
)
const step2QuickPreview = computed(() => toValue(step2Ref.value?.quickPreview) ?? undefined)
const step2StructureMode = computed(
  () => toValue(step2Ref.value?.selectedMode) ?? (wizardState.value.structure_mode as string) ?? 'none',
)

const step3ClientPreviewTree = computed(() => toValue(step3Ref.value?.clientPreviewTree) ?? undefined)
const step3UnitsCount = computed(() => {
  const fromForm = toValue(step3Ref.value?.estimatedUnitsCount)
  if (fromForm != null) return fromForm

  // fallback: unidades ya guardadas en servidor
  return (preview.value as any)?.counts?.units ?? null
})
const step3StructureMode = computed(() => (wizardState.value.structure_mode as string) ?? 'none')
// const step3UnitsCount = computed(() => (preview.value as any)?.counts?.units ?? 0)
const step4StructureMode = computed(() => (wizardState.value.structure_mode as string) ?? 'none')

const showAside = computed(() => currentStep.value <= 5)

const breadcrumbs = computed(() => [
  { label: t('admin.sidebar.residential_properties'), href: '/admin/residential_properties' },
  { label: t('admin.property_setup.wizard.breadcrumb') },
])

const stepTitle = computed(() => t(`admin.property_setup.step${currentStep.value}.title`))

const continueLabel = computed(() => {
  if (currentStep.value === 4) return t('admin.property_setup.wizard.actions.continue_to_confirm')
  return t('admin.property_setup.wizard.actions.continue')
})

const step1Values = computed(() => ({
  name: (props.property?.name as string) ?? '',
  property_type: (props.property?.property_type as string) ?? propertyTypes.value[0],
  address_line: (props.property?.address_line as string) ?? '',
  city: (props.property?.city as string) ?? '',
  region: (props.property?.region as string) ?? '',
  country: (props.property?.country as string) ?? 'Chile',
  timezone: (props.property?.timezone as string) ?? 'America/Santiago',
}))

const step1Preview = computed(() => toValue(step1Ref.value?.preview) ?? step1Values.value)

function onContinue() {
  if (!validateCurrentStep()) return

  submitting.value = true
  const payload = buildPayload()

  if (currentStep.value === 1 && !propertyId.value) {
    router.post('/admin/property_setup/wizard', { setup: payload }, { onFinish: () => { submitting.value = false } })
    return
  }

  if (!propertyId.value) {
    submitting.value = false
    return
  }

  pendingConfirmPayload.value = payload
  router.post(`/admin/property_setup/wizard/${propertyId.value}/advance`, { setup: payload }, {
    onFinish: () => { submitting.value = false },
  })
}

function confirmReset() {
  if (!propertyId.value || !pendingConfirmPayload.value) return

  submitting.value = true
  router.post(
    `/admin/property_setup/wizard/${propertyId.value}/advance`,
    { setup: pendingConfirmPayload.value, confirmed: 'true' },
    {
      onFinish: () => {
        submitting.value = false
        pendingConfirmPayload.value = null
      },
    },
  )
}

function cancelReset() {
  pendingConfirmPayload.value = null
}

function goBack() {
  if (!propertyId.value) return
  submitting.value = true
  router.post(`/admin/property_setup/wizard/${propertyId.value}/back`, {}, {
    onFinish: () => { submitting.value = false },
  })
}

function onClose() {
  router.visit('/admin/residential_properties')
}

function onCancel() {
  if (!propertyId.value) {
    router.visit('/admin/residential_properties')
    return
  }

  if (props.property?.status === 'draft') {
    const deleteDraft = window.confirm(t('admin.property_setup.wizard.cancel.draft_confirm'))
    submitting.value = true
    router.post(`/admin/property_setup/wizard/${propertyId.value}/cancel`, { delete_draft: deleteDraft }, {
      onFinish: () => { submitting.value = false },
    })
    return
  }

  router.visit('/admin/residential_properties')
}

function onConfirm() {
  if (!propertyId.value) return
  submitting.value = true
  router.post(`/admin/property_setup/wizard/${propertyId.value}/confirm`, {}, {
    onFinish: () => { submitting.value = false },
  })
}

function onSaveCreated() {
  if (!propertyId.value) return
  submitting.value = true
  router.post(`/admin/property_setup/wizard/${propertyId.value}/complete`, {}, {
    onFinish: () => { submitting.value = false },
  })
}

// Configured/active edits have nothing left to persist (steps already saved
// incrementally); saving just shows the completion view without a status
// transition (enable-wizard-editing-created-state).
function onSaveExisting() {
  if (!propertyId.value) return
  router.visit(`/admin/property_setup/wizard/${propertyId.value}?completed=true`)
}

function buildPayload() {
  if (currentStep.value === 1) return step1Ref.value?.getValues() ?? {}
  if (currentStep.value === 2) return step2Ref.value?.getValues() ?? {}
  if (currentStep.value === 3) return step3Ref.value?.getValues() ?? {}
  return {}
}

function validateCurrentStep(): boolean {
  if (currentStep.value === 1) return step1Ref.value?.validate?.() ?? true
  if (currentStep.value === 2) return step2Ref.value?.validate?.() ?? true
  if (currentStep.value === 3) return step3Ref.value?.validate?.() ?? true
  return true
}
</script>
