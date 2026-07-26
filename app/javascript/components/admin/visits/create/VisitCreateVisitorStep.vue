<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <h3 class="text-base font-semibold">{{ t('admin.visits.new.visitor.title') }}</h3>
      <p class="text-sm text-muted-foreground">{{ t('admin.visits.new.visitor.description') }}</p>
    </div>

    <div class="flex flex-wrap gap-2">
      <Button
        type="button"
        :variant="form.visitor_mode === 'search' ? 'default' : 'outline'"
        size="sm"
        @click="switchMode('search')"
      >
        {{ t('admin.visits.new.visitor.modes.search') }}
      </Button>
      <Button
        type="button"
        :variant="form.visitor_mode === 'create' ? 'default' : 'outline'"
        size="sm"
        @click="switchMode('create')"
      >
        {{ t('admin.visits.new.visitor.modes.create') }}
      </Button>
    </div>

    <div v-if="form.visitor_mode === 'search'" class="space-y-4">
      <div class="flex gap-2">
        <Input
          v-model="search"
          type="search"
          :placeholder="t('admin.visits.new.visitor.search.placeholder')"
          @keydown.enter.prevent="onSearch"
        />
        <Button type="button" variant="outline" :disabled="loading" @click="onSearch">
          <Search class="size-4" />
          {{ t('common.actions.search') }}
        </Button>
      </div>

      <div v-if="loading" class="text-sm text-muted-foreground">
        {{ t('admin.visits.new.visitor.search.loading') }}
      </div>

      <div
        v-else-if="people.length === 0"
        class="rounded-lg border border-dashed p-4 text-sm text-muted-foreground"
      >
        {{ t('admin.visits.new.visitor.search.empty') }}
      </div>

      <div v-else class="space-y-2">
        <button
          v-for="person in people"
          :key="person.id"
          type="button"
          class="flex w-full items-center gap-3 rounded-lg border bg-card p-4 text-left transition-colors hover:bg-muted/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          :class="form.visitor_person_id === person.id ? 'border-primary ring-1 ring-primary/30' : ''"
          @click="selectPerson(person)"
        >
          <Avatar class="size-10">
            <AvatarFallback>{{ personInitials(person.display_name) }}</AvatarFallback>
          </Avatar>
          <span class="min-w-0 flex-1">
            <span class="block text-sm font-semibold">{{ person.display_name }}</span>
            <span class="block text-xs text-muted-foreground">
              {{ person.document_number || '—' }}
              <span v-if="person.phone"> · {{ person.phone }}</span>
            </span>
          </span>
        </button>
      </div>

      <FieldError
        v-if="fieldErrors.visitor_person_id"
        :errors="translateErrors([fieldErrors.visitor_person_id])"
      />
    </div>

    <div v-else class="space-y-4">
      <FieldGroup class="grid gap-4 md:grid-cols-2">
        <Field>
          <FieldLabel for="visit-visitor-document">
            {{ t('admin.visits.new.visitor.create.fields.document') }}
          </FieldLabel>
          <Input
            id="visit-visitor-document"
            v-model="form.visitor.document_number"
            :placeholder="t('admin.people.input.document_number.placeholder')"
            :aria-invalid="!!fieldErrors['visitor.document_number']"
          />
          <FieldError
            v-if="fieldErrors['visitor.document_number']"
            :errors="translateErrors([fieldErrors['visitor.document_number']])"
          />
        </Field>

        <Field>
          <FieldLabel for="visit-visitor-phone">
            {{ t('admin.visits.new.visitor.create.fields.phone') }}
          </FieldLabel>
          <Input
            id="visit-visitor-phone"
            v-model="form.visitor.phone"
            :placeholder="t('admin.people.input.phone.placeholder')"
          />
        </Field>

        <Field>
          <FieldLabel for="visit-visitor-first-name">
            {{ t('admin.people.input.first_name.label') }}
          </FieldLabel>
          <Input
            id="visit-visitor-first-name"
            v-model="form.visitor.first_name"
            :placeholder="t('admin.people.input.first_name.placeholder')"
            :aria-invalid="!!fieldErrors['visitor.first_name']"
          />
          <FieldError
            v-if="fieldErrors['visitor.first_name']"
            :errors="translateErrors([fieldErrors['visitor.first_name']])"
          />
        </Field>

        <Field>
          <FieldLabel for="visit-visitor-last-name">
            {{ t('admin.people.input.last_name.label') }}
          </FieldLabel>
          <Input
            id="visit-visitor-last-name"
            v-model="form.visitor.last_name"
            :placeholder="t('admin.people.input.last_name.placeholder')"
            :aria-invalid="!!fieldErrors['visitor.last_name']"
          />
          <FieldError
            v-if="fieldErrors['visitor.last_name']"
            :errors="translateErrors([fieldErrors['visitor.last_name']])"
          />
        </Field>
      </FieldGroup>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Search } from 'lucide-vue-next'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { useTranslateErrors } from '@/lib/composables/i18n/translate_errors'
import { useUnitAddOwnerPeopleSearch } from '@/lib/composables/unit/useUnitAddOwnerPeopleSearch'
import { buildDisplayName } from '@/lib/schemas/unit_ownership'
import type { VisitCreateForm, VisitCreateVisitorMode } from '@/lib/schemas/visit_create'
import { personInitials } from '@/lib/utils/unit'
import type { Person } from '@/types/person'

const form = defineModel<VisitCreateForm>('form', { required: true })

const props = defineProps<{
  fieldErrors?: Record<string, string | undefined>
}>()

const emit = defineEmits<{
  (e: 'visitor-selected', name: string): void
}>()

const { t } = useI18n()
const { translateErrors } = useTranslateErrors()
const { people, loading, search: fetchPeople } = useUnitAddOwnerPeopleSearch()
const search = ref('')

const fieldErrors = computed(() => props.fieldErrors ?? {})

function switchMode(mode: VisitCreateVisitorMode) {
  form.value.visitor_mode = mode
  if (mode === 'create') {
    form.value.visitor_person_id = ''
  }
}

function onSearch() {
  fetchPeople(search.value, 1, 10)
}

function selectPerson(person: Person) {
  if (!person.id) return
  form.value.visitor_person_id = person.id
  emit('visitor-selected', person.display_name)
}

watch(
  () => [form.value.visitor.first_name, form.value.visitor.last_name],
  () => {
    if (form.value.visitor_mode !== 'create') return
    emit(
      'visitor-selected',
      buildDisplayName(form.value.visitor.first_name, form.value.visitor.last_name),
    )
  },
)

onMounted(() => {
  fetchPeople('', 1, 10)
})
</script>
