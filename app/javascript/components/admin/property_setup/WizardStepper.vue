<template>
  <nav aria-label="Wizard progress" class="flex flex-wrap items-center gap-2">
    <div
      v-for="item in steps"
      :key="item.id"
      class="flex items-center gap-2 text-sm"
      :class="item.id === currentStep ? 'text-primary font-medium' : 'text-muted-foreground'"
    >
      <span
        class="inline-flex size-7 items-center justify-center rounded-full border"
        :class="item.done ? 'bg-primary text-primary-foreground border-primary' : ''"
      >
        <Check v-if="item.done" class="size-4" />
        <span v-else>{{ item.id }}</span>
      </span>
      <span class="hidden sm:inline">{{ item.label }}</span>
    </div>
  </nav>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check } from 'lucide-vue-next'

const props = defineProps<{
  currentStep: number
  completedThrough: number
}>()

const { t } = useI18n()

const steps = computed(() =>
  [1, 2, 3, 4, 5].map((id) => ({
    id,
    label: t(`admin.property_setup.wizard.steps.${id}`),
    done: id <= props.completedThrough,
  })),
)
</script>
