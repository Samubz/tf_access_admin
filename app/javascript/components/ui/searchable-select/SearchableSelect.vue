<template>
  <Combobox
    :id="id"
    v-model="model"
    v-model:open="open"
    :disabled="disabled"
    :ignore-filter="true"
    :reset-search-term-on-select="true"
  >
    <ComboboxAnchor class="relative w-full">
      <ComboboxTrigger as-child>
        <Button
          type="button"
          variant="outline"
          role="combobox"
          :aria-expanded="open"
          :aria-invalid="invalid || undefined"
          :disabled="disabled"
          class="w-full justify-start pr-16 font-normal"
          :class="!knownOption && 'text-muted-foreground'"
        >
          <span class="truncate">{{ knownOption ? knownOption.label : placeholder }}</span>
        </Button>
      </ComboboxTrigger>
      <div
        class="pointer-events-none absolute top-1/2 right-3 flex -translate-y-1/2 items-center gap-2"
      >
        <button
          v-if="model && !disabled"
          type="button"
          :aria-label="t('common.searchable_select.clear')"
          class="text-muted-foreground hover:text-foreground pointer-events-auto flex size-5 items-center justify-center rounded-sm"
          @click.prevent.stop="clear"
          @mousedown.prevent.stop
          @pointerdown.prevent.stop
        >
          <X class="size-4" />
        </button>
        <Loader2 v-if="loading" class="text-muted-foreground size-4 shrink-0 animate-spin" />
        <ChevronsUpDown v-else class="text-muted-foreground size-4 shrink-0 opacity-50" />
      </div>
    </ComboboxAnchor>

    <ComboboxList
      side="bottom"
      :avoid-collisions="false"
      class="w-(--reka-combobox-trigger-width) p-0"
      @open-auto-focus.prevent
    >
      <div class="flex h-9 items-center gap-2 border-b px-3">
        <Search class="size-4 shrink-0 opacity-50" />
        <Input
          :model-value="query"
          type="search"
          autocomplete="off"
          :placeholder="t('common.actions.search')"
          class="h-10 border-0 px-0 py-3 shadow-none focus-visible:ring-0"
          @keydown.stop
          @update:model-value="onQueryChange"
        />
      </div>

      <ComboboxViewport @scroll.passive="onScroll">
        <ComboboxEmpty v-if="!loading && options.length === 0">
          {{ error ? errorText ?? t('common.searchable_select.error') : emptyText ?? t('common.searchable_select.empty') }}
        </ComboboxEmpty>

        <ComboboxItem
          v-for="option in options"
          :key="option.value"
          :value="option.value"
          :text-value="option.label"
          @select="() => onSelect(option)"
        >
          <Check
            class="size-4 shrink-0"
            :class="model === option.value ? 'opacity-100' : 'opacity-0'"
          />
          <span class="flex min-w-0 flex-col">
            <span class="truncate">{{ option.label }}</span>
            <span v-if="option.description" class="text-muted-foreground truncate text-xs">
              {{ option.description }}
            </span>
          </span>
        </ComboboxItem>

        <div v-if="loading" class="text-muted-foreground p-2 text-center text-xs">
          {{ loadingText ?? t('common.searchable_select.loading') }}
        </div>
      </ComboboxViewport>
    </ComboboxList>
  </Combobox>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check, ChevronsUpDown, Loader2, Search, X } from 'lucide-vue-next'
import {
  Combobox,
  ComboboxAnchor,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxTrigger,
  ComboboxViewport,
} from '@/components/ui/combobox'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import type { SearchableSelectOption } from './types'

const props = withDefaults(
  defineProps<{
    id?: string
    options?: SearchableSelectOption[]
    selectedOption?: SearchableSelectOption | null
    placeholder?: string
    loadingText?: string
    emptyText?: string
    errorText?: string
    disabled?: boolean
    invalid?: boolean
    loading?: boolean
    error?: boolean
    hasMore?: boolean
  }>(),
  {
    options: () => [],
    hasMore: false,
  },
)

const emit = defineEmits<{
  (e: 'option-selected', option: SearchableSelectOption | null): void
  (e: 'search', query: string): void
  (e: 'load-more'): void
}>()

const model = defineModel<string | null | undefined>()

const { t } = useI18n()

const open = ref(false)
const query = ref('')

const knownOption = computed<SearchableSelectOption | null>(() => {
  if (props.selectedOption && props.selectedOption.value === model.value) return props.selectedOption
  return props.options.find((option) => option.value === model.value) ?? props.selectedOption ?? null
})

function onQueryChange(value: string | number) {
  const nextQuery = String(value)
  query.value = nextQuery
  emit('search', nextQuery)
}

function onSelect(option: SearchableSelectOption) {
  model.value = option.value
  emit('option-selected', option)
}

function clear() {
  model.value = undefined
  query.value = ''
  emit('search', '')
  emit('option-selected', null)
}

function onScroll(event: Event) {
  if (props.loading || !props.hasMore) return

  const target = event.target
  if (!(target instanceof HTMLElement)) return
  if (target.scrollHeight - target.scrollTop - target.clientHeight > 40) return

  emit('load-more')
}
</script>
