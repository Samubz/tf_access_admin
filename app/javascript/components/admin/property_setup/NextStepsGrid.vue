<template>
  <section class="space-y-4">
    <h3 class="text-sm font-medium">{{ title }}</h3>
    <div class="grid gap-3 md:grid-cols-2">
      <Card
        v-for="action in actions"
        :key="action.key"
        class="shadow-none !p-2"
        :class="action.recommended ? 'border-green-500 ring-1 ring-green-200' : ''"
      >
        <CardContent class="flex h-full flex-col gap-4 px-2">
          <div class="flex items-start justify-between gap-3">
            <span
              class="inline-flex size-10 shrink-0 items-center justify-center rounded-full"
              :class="action.recommended ? 'bg-green-100 text-green-700' : 'bg-muted text-muted-foreground'"
            >
              <component :is="action.icon" class="size-4" />
            </span>
            <Badge
              v-if="action.recommended"
              class="border-transparent bg-green-100 font-normal text-green-800 hover:bg-green-100"
            >
              {{ recommendedLabel }}
            </Badge>
          </div>
          <div class="space-y-1">
            <p class="text-sm font-medium">{{ action.title }}</p>
            <p class="text-muted-foreground text-xs leading-relaxed">{{ action.description }}</p>
          </div>
          <Button
            v-if="action.href && !action.disabled"
            as="a"
            :href="action.href"
            :variant="action.recommended ? 'default' : 'outline'"
            class="mt-auto w-full"
          >
            {{ action.buttonLabel }}
          </Button>
          <Button v-else variant="outline" class="mt-auto w-full" disabled>
            {{ action.buttonLabel }}
          </Button>
        </CardContent>
      </Card>
    </div>
  </section>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import type { NextStepAction } from '@/lib/composables/property_setup/useNextStepActions'

defineProps<{
  title: string
  actions: NextStepAction[]
}>()

const { t } = useI18n()
const recommendedLabel = t('admin.property_setup.step5.completed.next_steps.recommended_badge')
</script>
