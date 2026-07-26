<template>
  <SearchableSelect
    :id="id"
    v-model="model"
    :options="options"
    :selected-option="selectedOption"
    :placeholder="placeholder"
    :loading-text="loadingText"
    :empty-text="emptyText"
    :error-text="errorText"
    :disabled="disabled"
    :invalid="invalid"
    :loading="loading"
    :error="error"
    :has-more="hasMore"
    @search="onSearch"
    @load-more="loadMore"
    @option-selected="emit('option-selected', $event)"
  />
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useDebounceFn } from '@vueuse/core'
import SearchableSelect from './SearchableSelect.vue'
import type { SearchableSelectLoader, SearchableSelectOption } from './types'

const props = withDefaults(
  defineProps<{
    id?: string
    loadOptions: SearchableSelectLoader
    selectedOption?: SearchableSelectOption | null
    placeholder?: string
    loadingText?: string
    emptyText?: string
    errorText?: string
    disabled?: boolean
    invalid?: boolean
    debounceMs?: number
  }>(),
  {
    debounceMs: 300,
  },
)

const emit = defineEmits<{
  (e: 'option-selected', option: SearchableSelectOption | null): void
}>()

const model = defineModel<string | null | undefined>()

const query = ref('')
const options = ref<SearchableSelectOption[]>([])
const page = ref(1)
const hasMore = ref(false)
const loading = ref(false)
const error = ref(false)

let requestToken = 0

async function runSearch(reset: boolean) {
  const token = ++requestToken
  const requestedPage = reset ? 1 : page.value
  loading.value = true

  try {
    const result = await props.loadOptions({ query: query.value.trim(), page: requestedPage })
    if (token !== requestToken) return

    options.value = reset ? result.options : mergeOptions(options.value, result.options)
    hasMore.value = result.hasMore
    page.value = requestedPage + 1
    error.value = false
  } catch {
    if (token !== requestToken) return
    error.value = true
  } finally {
    if (token === requestToken) loading.value = false
  }
}

function mergeOptions(
  current: SearchableSelectOption[],
  next: SearchableSelectOption[],
): SearchableSelectOption[] {
  const seen = new Set(current.map((option) => option.value))
  const merged = [...current]

  for (const option of next) {
    if (seen.has(option.value)) continue
    merged.push(option)
    seen.add(option.value)
  }

  return merged
}

const debouncedSearch = useDebounceFn(() => runSearch(true), () => props.debounceMs)

function onSearch(value: string) {
  query.value = value
  debouncedSearch()
}

function loadMore() {
  if (loading.value || !hasMore.value) return
  void runSearch(false)
}

watch(
  () => props.disabled,
  (disabled) => {
    if (disabled) return
    if (options.value.length === 0 && !loading.value) void runSearch(true)
  },
  { immediate: true },
)
</script>
