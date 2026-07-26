<template>
  <div v-if="selectedMode === 'manual'" class="space-y-4">
    <template v-if="hasSections">
      <Alert class="border-blue-200 bg-blue-50 text-blue-900 [&>svg]:text-blue-600">
        <Info class="size-4" />
        <AlertDescription>{{ t('admin.property_setup.step2.manual.hints.actions') }}</AlertDescription>
      </Alert>
    </template>
    <div class="w-full flex flex-wrap items-start justify-start gap-3">
      <p class="text-muted-foreground max-w-2xl text-sm">
        {{ t('admin.property_setup.step2.manual.rule_hint') }}
      </p>
      <div class="w-full flex justify-end">
        <Button type="button" class="shrink-0" @click="openAddRoot">
          <Plus class="size-4" />
          {{ t('admin.property_setup.step2.manual.add_root') }}
        </Button>
      </div>
    </div>

    <div v-if="hasSections" class="text-muted-foreground flex flex-wrap gap-4 text-xs">
      <span>{{ t('admin.property_setup.step2.manual.summary.total', { count: totalCount }) }}</span>
      <span>{{ t('admin.property_setup.step2.manual.summary.leaf', { count: leafForUnitsCount }) }}</span>
    </div>

    <p v-if="!hasSections" class="text-muted-foreground rounded-lg border border-dashed p-8 text-center text-sm">
      {{ t('admin.property_setup.step2.manual.empty') }}
    </p>

    <ul v-else class="space-y-1">
      <li v-for="root in tree" :key="root.id" class="space-y-0.5">
        <ManualSectionTreeRow
          :section="root"
          :is-root="true"
          @edit="openEdit"
          @add-child="openAddChild"
          @move="openMove"
          @delete="openDelete"
        />

        <ul
          v-if="root.children?.length"
          class="relative m-0 ml-5 list-none space-y-0.5 border-l border-dashed border-border/80 py-0.5 pl-3"
        >
          <li v-for="child in root.children" :key="child.id">
            <ManualSectionTreeRow
              :section="child"
              :is-root="false"
              @edit="openEdit"
              @move="openMove"
              @delete="openDelete"
            />
          </li>
        </ul>
      </li>
    </ul>

    <!-- Create dialog -->
    <Dialog :open="createOpen" @update:open="onCreateOpenChange">
      <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>
            {{
              createParent
                ? t('admin.property_setup.step2.manual.create.title_child')
                : t('admin.property_setup.step2.manual.create.title_root')
            }}
          </DialogTitle>
          <DialogDescription v-if="createParent">
            {{ t('admin.property_setup.step2.manual.create.parent_label', { name: createParent.name }) }}
          </DialogDescription>
        </DialogHeader>

        <div v-if="createParent" class="rounded-lg border bg-muted/30 px-3 py-2 text-sm">
          <span class="text-muted-foreground">{{ t('admin.property_setup.step2.manual.parent') }}:</span>
          <span class="ml-1 font-medium">{{ createParent.name }}</span>
        </div>

        <Tabs v-model="createForm.mode" class="gap-4">
          <TabsList class="grid w-full grid-cols-2">
            <TabsTrigger value="individual">
              {{ t('admin.property_setup.step2.manual.create.tab_individual') }}
            </TabsTrigger>
            <TabsTrigger value="multiple">
              {{ t('admin.property_setup.step2.manual.create.tab_multiple') }}
            </TabsTrigger>
          </TabsList>

          <TabsContent value="individual" class="space-y-4 pt-2">
            <Field :data-invalid="!!createErrors.name">
              <FieldLabel>{{ t('admin.property_setup.step2.manual.name') }}</FieldLabel>
              <Input v-model="createForm.name" :aria-invalid="!!createErrors.name" />
              <FieldError v-if="createErrors.name" :errors="translateErrors([createErrors.name])" />
            </Field>
          </TabsContent>

          <TabsContent value="multiple" class="space-y-4 pt-2">
            <div class="grid grid-cols-2 gap-3">
              <Field :data-invalid="!!createErrors.count">
                <FieldLabel>{{ t('admin.property_setup.step2.manual.create.count') }}</FieldLabel>
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
                <FieldLabel>{{ t('admin.property_setup.step2.manual.create.prefix') }}</FieldLabel>
                <Input v-model="createForm.prefix" :aria-invalid="!!createErrors.prefix" />
                <FieldError v-if="createErrors.prefix" :errors="translateErrors([createErrors.prefix])" />
              </Field>
            </div>

            <Field>
              <FieldLabel>{{ t('admin.property_setup.step2.manual.create.format') }}</FieldLabel>
              <select
                v-model="createForm.suffix_type"
                class="border-input bg-background flex h-10 w-full rounded-md border px-3 py-2 text-sm"
              >
                <option value="letter">{{ t('admin.property_setup.step2.manual.create.format_letter') }}</option>
                <option value="number">{{ t('admin.property_setup.step2.manual.create.format_number') }}</option>
              </select>
            </Field>
          </TabsContent>
        </Tabs>

        <Field :data-invalid="!!createErrors.section_type">
          <FieldLabel>{{ t('admin.property_setup.step2.manual.type') }}</FieldLabel>
          <select
            v-model="createForm.section_type"
            class="border-input bg-background flex h-10 w-full rounded-md border px-3 py-2 text-sm"
            :aria-invalid="!!createErrors.section_type"
          >
            <option v-for="type in sectionTypes" :key="type" :value="type">{{ typeLabel(type) }}</option>
          </select>
          <FieldError v-if="createErrors.section_type" :errors="translateErrors([createErrors.section_type])" />
          <p v-if="showCreateFormatWarning" class="text-xs text-amber-600">
            {{ t('admin.property_setup.step2.manual.format_warning', { types: recommendedLabels }) }}
          </p>
        </Field>

        <div v-if="namePreview.length" class="space-y-2">
          <p class="text-muted-foreground text-xs">
            {{ t('admin.property_setup.step2.manual.create.preview_will_create') }}
            {{ namePreviewText }}
          </p>
          <div class="flex flex-wrap gap-1.5">
            <span
              v-for="(name, index) in namePreview"
              :key="`${name}-${index}`"
              class="inline-flex items-center gap-1.5 rounded-full border bg-muted/40 px-2.5 py-1 text-xs font-medium"
            >
              <component :is="iconFor(createForm.section_type)" class="text-muted-foreground size-3.5" />
              {{ name }}
            </span>
          </div>
          <p v-if="skippedPreviewText" class="text-xs text-amber-700">
            {{ skippedPreviewText }}
          </p>
        </div>

        <p v-if="createInsufficientAvailable" class="text-destructive text-sm">
          {{ t('admin.property_setup.step2.manual.create.insufficient_available_names', { count: createForm.count }) }}
        </p>

        <Alert class="border-blue-200 bg-blue-50 text-blue-900 [&>svg]:text-blue-600">
          <Info class="size-4" />
          <AlertDescription>
            {{
              createParent
                ? t('admin.property_setup.step2.manual.create.info_child')
                : t('admin.property_setup.step2.manual.create.info_root')
            }}
          </AlertDescription>
        </Alert>

        <DialogFooter>
          <Button type="button" variant="outline" @click="createOpen = false">
            {{ t('admin.property_setup.step2.manual.create.cancel') }}
          </Button>
          <Button type="button" :disabled="submitting || createInsufficientAvailable" @click="submitCreate">
            {{ t('admin.property_setup.step2.manual.create.submit') }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Edit dialog -->
    <Dialog :open="editOpen" @update:open="onEditOpenChange">
      <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{{ t('admin.property_setup.step2.manual.edit.title') }}</DialogTitle>
          <DialogDescription>{{ t('admin.property_setup.step2.manual.edit.description') }}</DialogDescription>
        </DialogHeader>

        <div v-if="editTarget" class="space-y-1 rounded-lg border bg-muted/30 px-3 py-2 text-sm">
          <p>
            <span class="text-muted-foreground">{{ t('admin.property_setup.step2.manual.edit.current') }}:</span>
            <span class="ml-1 font-medium">{{ editTarget.name }}</span>
          </p>
          <p v-if="editParentName">
            <span class="text-muted-foreground">{{ t('admin.property_setup.step2.manual.edit.parent') }}:</span>
            <span class="ml-1 font-medium">{{ editParentName }}</span>
          </p>
        </div>

        <div class="space-y-4">
          <Field :data-invalid="!!editErrors.name">
            <FieldLabel>{{ t('admin.property_setup.step2.manual.name') }}</FieldLabel>
            <Input v-model="editForm.name" :aria-invalid="!!editErrors.name" />
            <FieldError v-if="editErrors.name" :errors="translateErrors([editErrors.name])" />
          </Field>

          <Field :data-invalid="!!editErrors.section_type">
            <FieldLabel>{{ t('admin.property_setup.step2.manual.type') }}</FieldLabel>
            <select
              v-model="editForm.section_type"
              class="border-input bg-background flex h-10 w-full rounded-md border px-3 py-2 text-sm"
            >
              <option v-for="type in sectionTypes" :key="type" :value="type">{{ typeLabel(type) }}</option>
            </select>
          </Field>
        </div>

        <Alert
          v-if="editTargetHasChildren"
          class="border-amber-200 bg-amber-50 text-amber-900 [&>svg]:text-amber-700"
        >
          <Info class="size-4" />
          <AlertDescription>{{ t('admin.property_setup.step2.manual.edit.warning_has_children') }}</AlertDescription>
        </Alert>

        <DialogFooter class="sm:justify-between">
          <Button
            type="button"
            variant="ghost"
            class="text-destructive hover:text-destructive mr-auto"
            @click="editOpen = false; openDelete(editTarget!)"
          >
            {{ t('admin.property_setup.step2.manual.actions.delete') }}
          </Button>
          <div class="flex gap-2">
            <Button type="button" variant="outline" @click="editOpen = false">
              {{ t('admin.property_setup.step2.manual.create.cancel') }}
            </Button>
            <Button type="button" :disabled="submitting" @click="submitEdit">
              {{ t('admin.property_setup.step2.manual.edit.submit') }}
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Move dialog -->
    <Dialog :open="moveOpen" @update:open="onMoveOpenChange">
      <DialogContent class="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{{ t('admin.property_setup.step2.manual.move.title') }}</DialogTitle>
          <DialogDescription>
            {{ t('admin.property_setup.step2.manual.move.description', { name: moveTarget?.name }) }}
          </DialogDescription>
        </DialogHeader>

        <Field>
          <FieldLabel>{{ t('admin.property_setup.step2.manual.move.parent_label') }}</FieldLabel>
          <select
            v-model="moveParentId"
            class="border-input bg-background flex h-10 w-full rounded-md border px-3 py-2 text-sm"
          >
            <option value="">{{ t('admin.property_setup.step2.manual.move.root_option') }}</option>
            <option v-for="option in moveParentOptions" :key="option.id" :value="option.id">
              {{ option.name }}
            </option>
          </select>
        </Field>

        <DialogFooter>
          <Button type="button" variant="outline" @click="moveOpen = false">
            {{ t('admin.property_setup.step2.manual.move.cancel') }}
          </Button>
          <Button type="button" :disabled="submitting" @click="submitMove">
            {{ t('admin.property_setup.step2.manual.move.submit') }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Delete confirmation -->
    <AlertDialog :open="deleteOpen" @update:open="(v: boolean) => (deleteOpen = v)">
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {{ t('admin.property_setup.step2.manual.delete.title', { name: deleteTarget?.name }) }}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {{ t('admin.property_setup.step2.manual.delete.guards') }}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{{ t('admin.property_setup.step2.manual.delete.cancel') }}</AlertDialogCancel>
          <AlertDialogAction :disabled="submitting" @click="submitDelete">
            {{ t('admin.property_setup.step2.manual.delete.confirm') }}
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
import { Info, Minus, Plus } from 'lucide-vue-next'
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
import ManualSectionTreeRow from '@/components/admin/property_setup/ManualSectionTreeRow.vue'
import { useSectionTypeIcon } from '@/lib/composables/property_section/useSectionTypeIcon'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { mapPropertySetupZodErrors } from '@/lib/schemas/property_setup'
import {
  propertySectionBatchCreateSchema,
  propertySectionStructureEditSchema,
} from '@/lib/schemas/property_section_structure'
import { mapServerErrorsToForm } from '@/lib/forms/map_server_errors'
import { formatFieldValueErrorToast } from '@/lib/forms/format_field_value_error_toast'
import {
  allocateSectionNames,
  normalizeSectionName,
  type SuffixType,
} from '@/lib/property_setup/structurePreview'

type SectionNode = {
  id: string
  name: string
  section_type: string
  children?: SectionNode[]
}

const props = defineProps<{
  propertyId: string
  sectionTypes: string[]
  recommendedSectionTypes?: string[]
  tree: SectionNode[]
  selectedMode: string
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const { iconFor } = useSectionTypeIcon()
const submitting = ref(false)

const UNIT_ELIGIBLE_TYPES = ['block', 'tower', 'floor']

const hasSections = computed(() => props.tree.length > 0)
const totalCount = computed(() => props.tree.reduce((acc, root) => acc + 1 + (root.children?.length ?? 0), 0))
const leafForUnitsCount = computed(() => {
  let count = 0
  for (const root of props.tree) {
    const children = root.children ?? []
    if (children.length === 0) {
      if (UNIT_ELIGIBLE_TYPES.includes(root.section_type)) count += 1
    } else {
      count += children.filter((c) => UNIT_ELIGIBLE_TYPES.includes(c.section_type)).length
    }
  }
  return count
})

const recommended = computed(() => props.recommendedSectionTypes ?? [])
const recommendedLabels = computed(() =>
  recommended.value.map((type) => typeLabel(type)).join(', '),
)

function typeLabel(type: string) {
  return t(`admin.property_sections.section_types.${type}`)
}

function findParentName(sectionId: string): string | null {
  for (const root of props.tree) {
    if (root.children?.some((child) => child.id === sectionId)) return root.name
  }
  return null
}

function sectionHasChildren(section: SectionNode): boolean {
  return (section.children?.length ?? 0) > 0
}

// --- Create -----------------------------------------------------------------
const createOpen = ref(false)
const createParent = ref<SectionNode | null>(null)
const createErrors = ref<Record<string, string>>({})
const createForm = reactive({
  mode: 'individual' as 'individual' | 'multiple',
  name: '',
  section_type: props.sectionTypes[0] ?? 'tower',
  prefix: '',
  suffix_type: 'letter' as SuffixType,
  count: '2',
})

function siblingNodesForCreate(): SectionNode[] {
  if (createParent.value) return createParent.value.children ?? []
  return props.tree
}

const siblingNormalizedNames = computed(() =>
  new Set(siblingNodesForCreate().map((section) => normalizeSectionName(section.name))),
)

const createNameAllocation = computed(() => {
  if (createForm.mode !== 'multiple') {
    return { names: [] as string[], skipped: [] as string[], insufficient: false }
  }

  const count = Number(createForm.count)
  if (!createForm.prefix || Number.isNaN(count) || count < 1) {
    return { names: [] as string[], skipped: [] as string[], insufficient: false }
  }

  return allocateSectionNames(
    createForm.prefix,
    createForm.suffix_type,
    count,
    siblingNormalizedNames.value,
  )
})

const namePreview = computed(() => createNameAllocation.value.names.slice(0, 6))

const namePreviewText = computed(() => {
  const all = createNameAllocation.value.names
  if (all.length === 0) return ''
  if (all.length <= 3) return all.join(', ')
  return `${all.slice(0, 2).join(', ')}, ..., ${all[all.length - 1]}`
})

const skippedPreviewText = computed(() => {
  const skipped = createNameAllocation.value.skipped
  if (skipped.length === 0) return ''
  return t('admin.property_setup.step2.manual.create.preview_skipped', {
    names: skipped.join(', '),
  })
})

const createInsufficientAvailable = computed(
  () => createForm.mode === 'multiple' && createNameAllocation.value.insufficient,
)

function createFormFieldValues(): Record<string, string | undefined> {
  return {
    name:
      createForm.mode === 'individual'
        ? createForm.name
        : createNameAllocation.value.names[0],
    prefix: createForm.prefix,
    count: createForm.count,
    section_type: typeLabel(createForm.section_type),
  }
}

function showCreateServerErrorToast(errors: Record<string, string | string[]>) {
  const message = formatFieldValueErrorToast(errors, createFormFieldValues())
  if (message) toast.error(message)
}

const showCreateFormatWarning = computed(
  () => recommended.value.length > 0 && !recommended.value.includes(createForm.section_type),
)

function resetCreateForm() {
  createForm.mode = 'individual'
  createForm.name = ''
  createForm.section_type = props.sectionTypes[0] ?? 'tower'
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

function openAddRoot() {
  createParent.value = null
  resetCreateForm()
  createOpen.value = true
}

function openAddChild(parent: SectionNode) {
  createParent.value = parent
  resetCreateForm()
  createForm.section_type = recommended.value[recommended.value.length - 1] ?? props.sectionTypes[0] ?? 'floor'
  createOpen.value = true
}

function onCreateOpenChange(value: boolean) {
  createOpen.value = value
  if (!value) createParent.value = null
}

function submitCreate() {
  const payload = {
    mode: createForm.mode,
    placement: createParent.value ? 'child' : 'root',
    section_type: createForm.section_type,
    parent_id: createParent.value?.id,
    name: createForm.mode === 'individual' ? createForm.name : undefined,
    prefix: createForm.mode === 'multiple' ? createForm.prefix : undefined,
    suffix_type: createForm.suffix_type,
    count: createForm.mode === 'multiple' ? createForm.count : undefined,
  }

  const result = propertySectionBatchCreateSchema.safeParse(payload)
  if (!result.success) {
    createErrors.value = mapPropertySetupZodErrors(result.error)
    return
  }

  if (createInsufficientAvailable.value) return

  createErrors.value = {}
  submitting.value = true
  router.post(
    `/admin/property_setup/wizard/${props.propertyId}/sections`,
    {
      property_section: {
        mode: createForm.mode,
        section_type: createForm.section_type,
        parent_id: createParent.value?.id ?? null,
        name: createForm.mode === 'individual' ? createForm.name : null,
        prefix: createForm.mode === 'multiple' ? createForm.prefix : null,
        suffix_type: createForm.suffix_type,
        count: createForm.mode === 'multiple' ? Number(createForm.count) : null,
      },
    },
    {
      preserveScroll: true,
      onSuccess: () => {
        createOpen.value = false
        createParent.value = null
      },
      onError: (errors) => {
        showCreateServerErrorToast(errors)
      },
      onFinish: () => {
        submitting.value = false
      },
    },
  )
}

// --- Edit -------------------------------------------------------------------
const editOpen = ref(false)
const editTarget = ref<SectionNode | null>(null)
const editErrors = ref<Record<string, string>>({})
const editForm = reactive({ name: '', section_type: 'tower' })

const editParentName = computed(() =>
  editTarget.value ? findParentName(editTarget.value.id) : null,
)

const editTargetHasChildren = computed(() =>
  editTarget.value ? sectionHasChildren(editTarget.value) : false,
)

function openEdit(section: SectionNode) {
  editTarget.value = section
  editForm.name = section.name
  editForm.section_type = section.section_type
  editErrors.value = {}
  editOpen.value = true
}

function onEditOpenChange(value: boolean) {
  editOpen.value = value
  if (!value) editTarget.value = null
}

function submitEdit() {
  if (!editTarget.value) return
  const isRoot = props.tree.some((root) => root.id === editTarget.value!.id)
  const result = propertySectionStructureEditSchema.safeParse({
    placement: isRoot ? 'root' : 'child',
    status: 'active',
    name: editForm.name,
    section_type: editForm.section_type,
  })
  if (!result.success) {
    editErrors.value = mapPropertySetupZodErrors(result.error)
    return
  }

  editErrors.value = {}
  submitting.value = true
  router.patch(
    `/admin/property_setup/wizard/${props.propertyId}/sections/${editTarget.value.id}`,
    {
      property_section: {
        name: editForm.name,
        section_type: editForm.section_type,
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

// --- Move -------------------------------------------------------------------
const moveOpen = ref(false)
const moveTarget = ref<SectionNode | null>(null)
const moveParentId = ref('')

// A section may only move under a root section (never a subsection), and
// never under itself (enable-wizard-editing-created-state).
const moveParentOptions = computed(() =>
  props.tree.filter((root) => root.id !== moveTarget.value?.id),
)

function openMove(section: SectionNode) {
  moveTarget.value = section
  moveParentId.value = findParentName(section.id)
    ? (props.tree.find((root) => root.children?.some((child) => child.id === section.id))?.id ?? '')
    : ''
  moveOpen.value = true
}

function onMoveOpenChange(value: boolean) {
  moveOpen.value = value
  if (!value) moveTarget.value = null
}

function submitMove() {
  if (!moveTarget.value) return
  submitting.value = true
  router.patch(
    `/admin/property_setup/wizard/${props.propertyId}/sections/${moveTarget.value.id}/move`,
    { property_section: { parent_id: moveParentId.value || null } },
    {
      preserveScroll: true,
      onSuccess: () => {
        moveOpen.value = false
        moveTarget.value = null
      },
      onError: (errors) => {
        const message = Object.values(errors).flat()[0]
        if (message) toast.error(String(message))
      },
      onFinish: () => {
        submitting.value = false
      },
    },
  )
}

// --- Delete -----------------------------------------------------------------
const deleteOpen = ref(false)
const deleteTarget = ref<SectionNode | null>(null)

function openDelete(section: SectionNode) {
  deleteTarget.value = section
  deleteOpen.value = true
}

function submitDelete() {
  if (!deleteTarget.value) return
  submitting.value = true
  router.delete(
    `/admin/property_setup/wizard/${props.propertyId}/sections/${deleteTarget.value.id}`,
    {
      preserveScroll: true,
      onSuccess: () => {
        deleteOpen.value = false
        deleteTarget.value = null
      },
      onFinish: () => {
        submitting.value = false
      },
    },
  )
}
</script>
