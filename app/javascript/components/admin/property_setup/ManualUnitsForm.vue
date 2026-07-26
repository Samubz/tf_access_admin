<template>
  <div class="space-y-4">
    <Alert class="border-blue-200 bg-blue-50 text-blue-900 [&>svg]:text-blue-600">
      <Info class="size-4" />
      <AlertDescription>{{ t('admin.property_setup.step3.manual.hint') }}</AlertDescription>
    </Alert>

    <p v-if="!hasEligibleSections" class="text-muted-foreground rounded-lg border border-dashed p-8 text-center text-sm">
      {{ t('admin.property_setup.step3.manual.no_eligible_sections') }}
    </p>

    <ul v-else class="space-y-1">
      <li v-for="root in tree" :key="root.id" class="space-y-0.5">
        <UnitSectionTreeRow
          :section="root"
          :eligible="isEligible(root)"
          :property-id="propertyId"
          @add-unit="openAdd"
          @edit="openEdit"
          @delete="openDelete"
        />

        <ul
          v-if="root.children?.length"
          class="relative m-0 ml-5 list-none space-y-0.5 border-l border-dashed border-border/80 py-0.5 pl-3"
        >
          <li v-for="child in root.children" :key="child.id" class="space-y-0.5">
            <UnitSectionTreeRow
              :section="child"
              :eligible="isEligible(child)"
              :property-id="propertyId"
              @add-unit="openAdd"
              @edit="openEdit"
              @delete="openDelete"
            />
          </li>
        </ul>
      </li>
    </ul>

    <!-- Add unit dialog -->
    <Dialog :open="createOpen" @update:open="onCreateOpenChange">
      <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{{ t('admin.property_setup.step3.manual.create.title') }}</DialogTitle>
          <DialogDescription v-if="createSection">
            {{ t('admin.property_setup.step3.manual.create.section_label', { name: createSection.name }) }}
          </DialogDescription>
        </DialogHeader>

        <Tabs v-model="createForm.mode" class="gap-4">
          <TabsList class="grid w-full grid-cols-2">
            <TabsTrigger value="individual">
              {{ t('admin.property_setup.step3.manual.create.tab_individual') }}
            </TabsTrigger>
            <TabsTrigger value="multiple">
              {{ t('admin.property_setup.step3.manual.create.tab_multiple') }}
            </TabsTrigger>
          </TabsList>

          <TabsContent value="individual" class="space-y-4 pt-2">
            <Field :data-invalid="!!createErrors.identifier">
              <FieldLabel>{{ t('admin.property_setup.step3.manual.identifier') }}</FieldLabel>
              <Input v-model="createForm.identifier" :aria-invalid="!!createErrors.identifier" />
              <FieldError v-if="createErrors.identifier" :errors="translateErrors([createErrors.identifier])" />
            </Field>
            <Field :data-invalid="!!createErrors.display_name">
              <FieldLabel>{{ t('admin.property_setup.step3.manual.display_name') }}</FieldLabel>
              <Input v-model="createForm.display_name" :aria-invalid="!!createErrors.display_name" />
              <FieldError v-if="createErrors.display_name" :errors="translateErrors([createErrors.display_name])" />
            </Field>
          </TabsContent>

          <TabsContent value="multiple" class="space-y-4 pt-2">
            <div class="grid grid-cols-2 gap-3">
              <Field :data-invalid="!!createErrors.count">
                <FieldLabel>{{ t('admin.property_setup.step3.manual.create.count') }}</FieldLabel>
                <div class="flex items-center gap-1">
                  <Button
                    type="button"
                    variant="outline"
                    size="icon"
                    class="size-9 shrink-0"
                    :disabled="Number(createForm.count) <= 1"
                    @click="decrementCount"
                  >
                    <Minus class="size-4" />
                  </Button>
                  <Input
                    v-model="createForm.count"
                    type="number"
                    min="1"
                    class="text-center"
                    :aria-invalid="!!createErrors.count"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    size="icon"
                    class="size-9 shrink-0"
                    @click="incrementCount"
                  >
                    <Plus class="size-4" />
                  </Button>
                </div>
                <FieldError v-if="createErrors.count" :errors="translateErrors([createErrors.count])" />
              </Field>

              <Field :data-invalid="!!createErrors.prefix">
                <FieldLabel>{{ t('admin.property_setup.step3.manual.create.prefix') }}</FieldLabel>
                <Input v-model="createForm.prefix" :aria-invalid="!!createErrors.prefix" />
                <FieldError v-if="createErrors.prefix" :errors="translateErrors([createErrors.prefix])" />
              </Field>
            </div>

            <Field>
              <FieldLabel>{{ t('admin.property_setup.step3.manual.create.format') }}</FieldLabel>
              <Select v-model="createForm.suffix_type">
                <SelectTrigger class="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="letter">{{ t('admin.property_setup.step3.manual.create.format_letter') }}</SelectItem>
                  <SelectItem value="number">{{ t('admin.property_setup.step3.manual.create.format_number') }}</SelectItem>
                </SelectContent>
              </Select>
            </Field>
          </TabsContent>
        </Tabs>

        <Field :data-invalid="!!createErrors.unit_type">
          <FieldLabel>{{ t('admin.property_setup.step3.manual.unit_type') }}</FieldLabel>
          <Select v-model="createForm.unit_type">
            <SelectTrigger class="w-full" :aria-invalid="!!createErrors.unit_type">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem v-for="type in unitTypes" :key="type" :value="type">{{ unitTypeLabel(type) }}</SelectItem>
            </SelectContent>
          </Select>
          <FieldError v-if="createErrors.unit_type" :errors="translateErrors([createErrors.unit_type])" />
        </Field>

        <Field :data-invalid="!!createErrors.area_m2">
          <FieldLabel>{{ t('admin.property_setup.step3.manual.area_m2') }}</FieldLabel>
          <Input v-model="createForm.area_m2" type="number" min="0" step="0.01" :aria-invalid="!!createErrors.area_m2" />
          <FieldError v-if="createErrors.area_m2" :errors="translateErrors([createErrors.area_m2])" />
        </Field>

        <div v-if="createForm.mode === 'multiple' && identifierPreview.length" class="space-y-2">
          <p class="text-muted-foreground text-xs">
            {{ t('admin.property_setup.step3.manual.create.preview_will_create') }}
          </p>
          <div class="flex flex-wrap gap-1.5">
            <span
              v-for="(identifier, index) in identifierPreview"
              :key="`${identifier}-${index}`"
              class="inline-flex items-center gap-1.5 rounded-full border bg-muted/40 px-2.5 py-1 text-xs font-medium"
            >
              <Home class="text-muted-foreground size-3.5" />
              {{ identifier }}
            </span>
          </div>
        </div>

        <p v-if="createInsufficientAvailable" class="text-destructive text-sm">
          {{ t('admin.property_setup.step3.manual.create.insufficient_available_identifiers', { count: createForm.count }) }}
        </p>

        <Alert class="border-blue-200 bg-blue-50 text-blue-900 [&>svg]:text-blue-600">
          <Info class="size-4" />
          <AlertDescription>
            {{ t('admin.property_setup.step3.manual.create.info', { name: createSection?.name }) }}
          </AlertDescription>
        </Alert>

        <DialogFooter>
          <Button type="button" variant="outline" @click="createOpen = false">
            {{ t('admin.property_setup.step3.manual.create.cancel') }}
          </Button>
          <Button type="button" :disabled="submitting || createInsufficientAvailable" @click="submitCreate">
            {{ t('admin.property_setup.step3.manual.create.submit') }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Edit unit dialog -->
    <Dialog :open="editOpen" @update:open="onEditOpenChange">
      <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{{ t('admin.property_setup.step3.manual.edit.title') }}</DialogTitle>
        </DialogHeader>

        <div class="space-y-4">
          <Field :data-invalid="!!editErrors.identifier">
            <FieldLabel>{{ t('admin.property_setup.step3.manual.identifier') }}</FieldLabel>
            <Input v-model="editForm.identifier" :aria-invalid="!!editErrors.identifier" />
            <FieldError v-if="editErrors.identifier" :errors="translateErrors([editErrors.identifier])" />
          </Field>
          <Field :data-invalid="!!editErrors.display_name">
            <FieldLabel>{{ t('admin.property_setup.step3.manual.display_name') }}</FieldLabel>
            <Input v-model="editForm.display_name" :aria-invalid="!!editErrors.display_name" />
            <FieldError v-if="editErrors.display_name" :errors="translateErrors([editErrors.display_name])" />
          </Field>
          <Field :data-invalid="!!editErrors.unit_type">
            <FieldLabel>{{ t('admin.property_setup.step3.manual.unit_type') }}</FieldLabel>
            <Select v-model="editForm.unit_type">
              <SelectTrigger class="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="type in unitTypes" :key="type" :value="type">{{ unitTypeLabel(type) }}</SelectItem>
              </SelectContent>
            </Select>
          </Field>
          <Field :data-invalid="!!editErrors.area_m2">
            <FieldLabel>{{ t('admin.property_setup.step3.manual.area_m2') }}</FieldLabel>
            <Input v-model="editForm.area_m2" type="number" min="0" step="0.01" :aria-invalid="!!editErrors.area_m2" />
            <FieldError v-if="editErrors.area_m2" :errors="translateErrors([editErrors.area_m2])" />
          </Field>
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" @click="editOpen = false">
            {{ t('admin.property_setup.step3.manual.create.cancel') }}
          </Button>
          <Button type="button" :disabled="submitting" @click="submitEdit">
            {{ t('admin.property_setup.step3.manual.edit.submit') }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Delete confirmation -->
    <AlertDialog :open="deleteOpen" @update:open="(v: boolean) => (deleteOpen = v)">
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {{ t('admin.property_setup.step3.manual.delete.title', { name: deleteTarget?.identifier }) }}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {{ t('admin.property_setup.step3.manual.delete.warning') }}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{{ t('admin.property_setup.step3.manual.delete.cancel') }}</AlertDialogCancel>
          <AlertDialogAction :disabled="submitting" @click="submitDelete">
            {{ t('admin.property_setup.step3.manual.delete.confirm') }}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import { Home, Info, Minus, Plus } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Field, FieldError, FieldLabel } from '@/components/ui/field'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
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
import UnitSectionTreeRow from '@/components/admin/property_setup/UnitSectionTreeRow.vue'
import type { UnitNode } from '@/components/admin/property_setup/UnitTreeRow.vue'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { manualUnitCreateSchema, manualUnitEditSchema, mapManualUnitZodErrors } from '@/lib/schemas/manual_unit'
import { mapServerErrorsToForm } from '@/lib/forms/map_server_errors'
import { formatFieldValueErrorToast } from '@/lib/forms/format_field_value_error_toast'
import {
  allocateUnitIdentifiers,
  normalizeUnitIdentifier,
  type SuffixType,
} from '@/lib/property_setup/manualUnitPreview'

type SectionNode = {
  id: string
  name: string
  section_type: string
  children?: SectionNode[]
  units?: UnitNode[]
}

const UNIT_ELIGIBLE_TYPES = ['block', 'tower', 'floor']

const props = defineProps<{
  propertyId: string
  unitTypes: string[]
  tree: SectionNode[]
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const submitting = ref(false)

function isEligible(section: SectionNode): boolean {
  return (section.children?.length ?? 0) === 0 && UNIT_ELIGIBLE_TYPES.includes(section.section_type)
}

const hasEligibleSections = computed(() => flatten(props.tree).some(isEligible))

function flatten(nodes: SectionNode[]): SectionNode[] {
  return nodes.flatMap((node) => [node, ...(node.children ?? [])])
}

function unitTypeLabel(type: string) {
  return t(`admin.units.unit_types.${type}`)
}

// --- Create -------------------------------------------------------------------
const createOpen = ref(false)
const createSection = ref<SectionNode | null>(null)
const createErrors = ref<Record<string, string>>({})
const createForm = reactive({
  mode: 'individual' as 'individual' | 'multiple',
  identifier: '',
  display_name: '',
  unit_type: props.unitTypes[0] ?? 'apartment',
  area_m2: '',
  prefix: '',
  suffix_type: 'letter' as SuffixType,
  count: '2',
})

function resetCreateForm() {
  createForm.mode = 'individual'
  createForm.identifier = ''
  createForm.display_name = ''
  createForm.unit_type = props.unitTypes[0] ?? 'apartment'
  createForm.area_m2 = ''
  createForm.prefix = ''
  createForm.suffix_type = 'letter'
  createForm.count = '2'
  createErrors.value = {}
}

function incrementCount() {
  createForm.count = String(Math.max(1, Number(createForm.count) + 1))
}

function decrementCount() {
  createForm.count = String(Math.max(1, Number(createForm.count) - 1))
}

function openAdd(section: SectionNode) {
  createSection.value = section
  resetCreateForm()
  createOpen.value = true
}

function onCreateOpenChange(value: boolean) {
  createOpen.value = value
  if (!value) createSection.value = null
}

const siblingNormalizedIdentifiers = computed(
  () => new Set((createSection.value?.units ?? []).map((unit) => normalizeUnitIdentifier(unit.identifier))),
)

const createIdentifierAllocation = computed(() => {
  if (createForm.mode !== 'multiple') return { identifiers: [] as string[], skipped: [] as string[], insufficient: false }

  const count = Number(createForm.count)
  if (!createForm.prefix || Number.isNaN(count) || count < 1) {
    return { identifiers: [] as string[], skipped: [] as string[], insufficient: false }
  }

  return allocateUnitIdentifiers(createForm.prefix, createForm.suffix_type, count, siblingNormalizedIdentifiers.value)
})

const identifierPreview = computed(() => createIdentifierAllocation.value.identifiers.slice(0, 6))
const createInsufficientAvailable = computed(
  () => createForm.mode === 'multiple' && createIdentifierAllocation.value.insufficient,
)

function showCreateServerErrorToast(errors: Record<string, string | string[]>) {
  const message = formatFieldValueErrorToast(errors, {
    identifier: createForm.mode === 'individual' ? createForm.identifier : identifierPreview.value[0],
    prefix: createForm.prefix,
    count: createForm.count,
  })
  if (message) toast.error(message)
}

function submitCreate() {
  const payload = {
    mode: createForm.mode,
    unit_type: createForm.unit_type,
    area_m2: createForm.area_m2,
    identifier: createForm.mode === 'individual' ? createForm.identifier : undefined,
    display_name: createForm.mode === 'individual' ? createForm.display_name : undefined,
    prefix: createForm.mode === 'multiple' ? createForm.prefix : undefined,
    suffix_type: createForm.suffix_type,
    count: createForm.mode === 'multiple' ? createForm.count : undefined,
  }

  const result = manualUnitCreateSchema.safeParse(payload)
  if (!result.success) {
    createErrors.value = mapManualUnitZodErrors(result.error)
    return
  }
  if (createInsufficientAvailable.value || !createSection.value) return

  createErrors.value = {}
  submitting.value = true

  const basePath = `/admin/property_setup/wizard/${props.propertyId}`
  const isMultiple = createForm.mode === 'multiple'
  const url = isMultiple ? `${basePath}/units` : `${basePath}/create_unit`
  const unitPayload = isMultiple
    ? {
        property_section_id: createSection.value.id,
        unit_type: createForm.unit_type,
        area_m2: createForm.area_m2 || null,
        prefix: createForm.prefix,
        suffix_type: createForm.suffix_type,
        count: Number(createForm.count),
      }
    : {
        property_section_id: createSection.value.id,
        unit_type: createForm.unit_type,
        identifier: createForm.identifier,
        display_name: createForm.display_name || null,
      }

  router.post(
    url,
    { unit: unitPayload },
    {
      preserveScroll: true,
      onSuccess: () => {
        createOpen.value = false
        createSection.value = null
      },
      onError: (errors) => {
        showCreateServerErrorToast(errors)
        createErrors.value = mapServerErrorsToForm(errors)
      },
      onFinish: () => {
        submitting.value = false
      },
    },
  )
}

// --- Edit -----------------------------------------------------------------
const editOpen = ref(false)
const editTarget = ref<UnitNode | null>(null)
const editErrors = ref<Record<string, string>>({})
const editForm = reactive({ identifier: '', display_name: '', unit_type: '', area_m2: '' })

function openEdit(unit: UnitNode) {
  editTarget.value = unit
  editForm.identifier = unit.identifier
  editForm.display_name = unit.display_name ?? ''
  editForm.unit_type = unit.unit_type
  editForm.area_m2 = unit.area_m2 != null ? String(unit.area_m2) : ''
  editErrors.value = {}
  editOpen.value = true
}

function onEditOpenChange(value: boolean) {
  editOpen.value = value
  if (!value) editTarget.value = null
}

function submitEdit() {
  if (!editTarget.value) return

  const result = manualUnitEditSchema.safeParse({
    identifier: editForm.identifier,
    display_name: editForm.display_name,
    unit_type: editForm.unit_type,
    area_m2: editForm.area_m2,
  })
  if (!result.success) {
    editErrors.value = mapManualUnitZodErrors(result.error)
    return
  }

  editErrors.value = {}
  submitting.value = true
  router.patch(
    `/admin/property_setup/wizard/${props.propertyId}/units/${editTarget.value.id}`,
    {
      unit: {
        identifier: editForm.identifier,
        display_name: editForm.display_name || null,
        unit_type: editForm.unit_type,
        area_m2: editForm.area_m2 || null,
      },
    },
    {
      preserveScroll: true,
      onSuccess: () => {
        editOpen.value = false
        editTarget.value = null
      },
      onError: (errors) => {
        editErrors.value = mapServerErrorsToForm(errors)
      },
      onFinish: () => {
        submitting.value = false
      },
    },
  )
}

// --- Delete -----------------------------------------------------------------
const deleteOpen = ref(false)
const deleteTarget = ref<UnitNode | null>(null)

function openDelete(unit: UnitNode) {
  deleteTarget.value = unit
  deleteOpen.value = true
}

function submitDelete() {
  if (!deleteTarget.value) return
  submitting.value = true
  router.delete(`/admin/property_setup/wizard/${props.propertyId}/units/${deleteTarget.value.id}`, {
    preserveScroll: true,
    onSuccess: () => {
      deleteOpen.value = false
      deleteTarget.value = null
    },
    onFinish: () => {
      submitting.value = false
    },
  })
}
</script>
