<template>
  <Sheet :open="open" @update:open="(value) => !value && $emit('close')">
    <SheetContent side="right" class="w-full sm:max-w-md overflow-y-auto">
      <SheetHeader>
        <SheetTitle>{{ t('admin.operational_roles.assignment_drawer.title') }}</SheetTitle>
        <SheetDescription>{{ t('admin.operational_roles.assignment_drawer.description') }}</SheetDescription>
      </SheetHeader>

      <form @submit.prevent="submit" class="mt-6 px-4 space-y-4">
        <div class="space-y-1.5">
          <label class="text-sm font-medium">{{ t('admin.operational_roles.assignment_drawer.label_operational_role') }}</label>
          <select
            v-model="form.role"
            required
            class="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
          >
            <option value="" disabled>{{ t('admin.operational_roles.assignment_drawer.label_operational_role_placeholder') }}</option>
            <option v-for="r in available_roles" :key="r.key" :value="r.key">{{ r.name }}</option>
          </select>
        </div>

        <div class="space-y-1.5">
          <label class="text-sm font-medium">{{ t('admin.operational_roles.assignment_drawer.label_user') }}</label>
          <select
            v-model="form.person_id"
            required
            class="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
          >
            <option value="" disabled>{{ t('admin.operational_roles.assignment_drawer.label_user_placeholder') }}</option>
            <option v-for="person in filteredPeople" :key="person.id" :value="person.id">
              {{ personLabel(person) }}
            </option>
          </select>
        </div>

        <div v-if="selectedRole" class="space-y-1.5">
          <label class="text-sm font-medium">{{ t('admin.operational_roles.assignment_drawer.label_scope') }}</label>
          <Input :model-value="selectedRole.scope_label" disabled />
        </div>

        <div class="space-y-1.5">
          <label class="text-sm font-medium">{{ t('admin.operational_roles.assignment_drawer.label_property') }}</label>
          <select
            v-model="form.residential_property_id"
            required
            class="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
          >
            <option value="" disabled>{{ t('admin.operational_roles.assignment_drawer.label_property_placeholder') }}</option>
            <option v-for="p in accessible_properties" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </div>

        <div class="space-y-1.5">
          <label class="text-sm font-medium">{{ t('admin.operational_roles.assignment_drawer.label_starts_at') }}</label>
          <DatePicker v-model="form.starts_at" />
        </div>

        <div class="space-y-1.5">
          <label class="text-sm font-medium">{{ t('admin.operational_roles.assignment_drawer.label_ends_at') }}</label>
          <DatePicker v-model="form.ends_at" />
        </div>

        <div class="space-y-1.5">
          <label class="text-sm font-medium">{{ t('admin.operational_roles.assignment_drawer.label_status') }}</label>
          <select v-model="form.status" class="w-full h-9 rounded-md border border-input bg-background px-3 text-sm">
            <option value="active">{{ t('admin.operational_roles.assignment_drawer.label_status_active') }}</option>
            <option value="inactive">{{ t('admin.operational_roles.assignment_drawer.label_status_inactive') }}</option>
          </select>
        </div>

        <div v-if="errors.length" class="rounded-md bg-destructive/10 border border-destructive/20 px-4 py-3">
          <p class="font-medium text-sm text-destructive mb-1">{{ t('admin.operational_roles.assignment_drawer.errors_heading') }}</p>
          <p v-for="(err, i) in errors" :key="i" class="text-sm text-destructive">{{ err }}</p>
        </div>

        <SheetFooter class="w-full justify-between flex-row pt-4">
          <Button type="button" variant="outline" @click="$emit('close')">{{ t('admin.operational_roles.assignment_drawer.button_cancel') }}</Button>
          <Button type="submit" :disabled="submitting">
            <span v-if="submitting">{{ t('admin.operational_roles.assignment_drawer.button_saving') }}</span>
            <span v-else>{{ t('admin.operational_roles.assignment_drawer.button_submit') }}</span>
          </Button>
        </SheetFooter>
      </form>
    </SheetContent>
  </Sheet>
</template>

<script setup lang="ts">
import { ref, watch, computed } from "vue"
import { router, usePage } from "@inertiajs/vue3"
import { useI18n } from "vue-i18n"
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription, SheetFooter } from "@/components/ui/sheet"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import DatePicker from "@/components/ui/datepicker/DatePicker.vue"
import { admin_operational_roles_assignments_path } from "@/routes"
import type { AccessibleProperty, AssignablePerson, AvailableRoleOption } from "@/types/operational_roles"

const ROLES_REQUIRING_USER = ["property_admin", "concierge"]

const { t } = useI18n()

const props = defineProps<{
  open: boolean
  available_roles: AvailableRoleOption[]
  accessible_properties: AccessibleProperty[]
  assignable_people: AssignablePerson[]
}>()

const emit = defineEmits<{ close: [] }>()

const submitting = ref(false)
const errors = ref<string[]>([])
const today = new Date().toISOString().slice(0, 10)

const form = ref({
  role: "",
  person_id: "",
  residential_property_id: "" as string,
  starts_at: today,
  ends_at: "",
  status: "active"
})

const selectedRole = computed(() => props.available_roles.find((r) => r.key === form.value.role))

const filteredPeople = computed(() => {
  if (ROLES_REQUIRING_USER.includes(form.value.role)) {
    return props.assignable_people.filter((person) => person.has_user)
  }
  return props.assignable_people
})

watch(() => props.open, (val) => {
  if (val) {
    form.value = {
      role: "",
      person_id: "",
      residential_property_id: "",
      starts_at: today,
      ends_at: "",
      status: "active"
    }
    errors.value = []
  }
})

const page = usePage()
watch(() => page.props.errors, (errs: Record<string, string | string[]> | undefined) => {
  if (errs?.base) errors.value = Array.isArray(errs.base) ? errs.base : [errs.base]
}, { deep: true })

function personLabel(person: AssignablePerson) {
  if (person.user_email) return `${person.display_name} (${person.user_email})`
  return `${person.display_name} — ${t('admin.operational_roles.assignment_drawer.label_user_no_account')}`
}

function submit() {
  submitting.value = true
  errors.value = []

  router.post(admin_operational_roles_assignments_path(), {
    role: form.value.role,
    person_id: form.value.person_id,
    residential_property_id: form.value.residential_property_id,
    starts_at: form.value.starts_at || undefined,
    ends_at: form.value.ends_at || undefined,
    status: form.value.status
  }, {
    onSuccess: () => { emit("close") },
    onError: (errs) => {
      errors.value = errs.base ? [errs.base].flat() : Object.values(errs).flat() as string[]
    },
    onFinish: () => { submitting.value = false }
  })
}
</script>
