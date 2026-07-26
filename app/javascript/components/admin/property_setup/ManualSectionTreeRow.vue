<template>
  <div
    class="group flex min-h-10 items-center gap-1 rounded-lg pr-1 transition-colors hover:bg-muted/50"
  >
    <span
      class="text-muted-foreground/50 flex size-7 shrink-0 cursor-grab items-center justify-center"
      aria-hidden="true"
    >
      <GripVertical class="size-4" />
    </span>

    <div
      class="flex size-8 shrink-0 items-center justify-center rounded-md border border-border/60 bg-muted/50"
    >
      <component :is="iconFor(section.section_type)" class="text-muted-foreground size-4" />
    </div>

    <div class="flex min-w-0 flex-1 items-center gap-2">
      <span class="truncate text-sm font-medium">{{ section.name }}</span>
      <Badge variant="secondary" class="shrink-0 font-normal">{{ typeLabel }}</Badge>
      <Badge
        variant="outline"
        class="shrink-0 font-normal"
        :class="isRoot ? 'border-blue-200 bg-blue-50 text-blue-700' : ''"
      >
        {{ levelLabel }}
      </Badge>
    </div>

    <DropdownMenu>
      <DropdownMenuTrigger as-child>
        <Button
          variant="ghost"
          size="icon"
          class="size-7 shrink-0 opacity-70 transition-opacity group-hover:opacity-100 data-[state=open]:opacity-100"
          :aria-label="t('admin.property_setup.step2.manual.actions.menu')"
          @click.stop
        >
          <MoreHorizontal class="size-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem @select="emit('edit', section)">
          <Pencil class="size-4" />
          {{ t('admin.property_setup.step2.manual.actions.edit') }}
        </DropdownMenuItem>
        <DropdownMenuItem v-if="isRoot" @select="emit('add-child', section)">
          <Plus class="size-4" />
          {{ t('admin.property_setup.step2.manual.actions.add_child') }}
        </DropdownMenuItem>
        <DropdownMenuItem @select="emit('move', section)">
          <Move class="size-4" />
          {{ t('admin.property_setup.step2.manual.actions.move') }}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem variant="destructive" @select="emit('delete', section)">
          <Trash2 class="size-4" />
          {{ t('admin.property_setup.step2.manual.actions.delete') }}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { GripVertical, MoreHorizontal, Move, Pencil, Plus, Trash2 } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useSectionTypeIcon } from '@/lib/composables/property_section/useSectionTypeIcon'

type SectionNode = {
  id: string
  name: string
  section_type: string
  children?: SectionNode[]
}

const props = defineProps<{
  section: SectionNode
  isRoot: boolean
}>()

const emit = defineEmits<{
  (e: 'edit', section: SectionNode): void
  (e: 'add-child', section: SectionNode): void
  (e: 'move', section: SectionNode): void
  (e: 'delete', section: SectionNode): void
}>()

const { t } = useI18n()
const { iconFor } = useSectionTypeIcon()

const typeLabel = computed(() => t(`admin.property_sections.section_types.${props.section.section_type}`))
const levelLabel = computed(() =>
  props.isRoot
    ? t('admin.property_setup.step2.manual.level.root')
    : t('admin.property_setup.step2.manual.level.child'),
)
</script>
