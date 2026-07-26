<template>
  <div class="rounded-lg border bg-card">
    <div class="px-6 py-4 border-b flex items-center justify-between gap-4">
      <div>
        <h2 class="font-semibold text-base">{{ t('admin.operational_roles.permissions_matrix.title') }}</h2>
        <p class="text-sm text-muted-foreground mt-0.5">{{ t('admin.operational_roles.permissions_matrix.subtitle') }}</p>
      </div>
      <div class="flex items-center gap-4 text-xs text-muted-foreground">
        <span class="inline-flex items-center gap-1"><span class="text-green-600">✓</span> {{ t('admin.operational_roles.permissions_matrix.legend_allowed') }}</span>
        <span class="inline-flex items-center gap-1"><span class="text-muted-foreground/40">✕</span> {{ t('admin.operational_roles.permissions_matrix.legend_denied') }}</span>
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-xs min-w-[700px]">
        <thead>
          <tr class="border-b bg-muted/30">
            <th class="text-left px-4 py-3 font-medium text-muted-foreground w-48">{{ t('common.capability') }}</th>
            <th
              v-for="role in roleColumns"
              :key="role.key"
              class="px-3 py-3 font-medium text-center text-muted-foreground whitespace-nowrap"
            >
              {{ role.label }}
            </th>
          </tr>
        </thead>
        <tbody>
          <template v-for="group in capability_matrix" :key="group.module_key">
            <tr class="bg-muted/20">
              <td :colspan="roleColumns.length + 1" class="px-4 py-2 font-semibold text-xs text-muted-foreground uppercase tracking-wide">
                {{ group.module }}
              </td>
            </tr>
            <tr
              v-for="cap in group.capabilities"
              :key="cap.key"
              class="border-b last:border-0 hover:bg-muted/10"
            >
              <td class="px-4 py-2.5">
                <p class="text-sm">{{ cap.label }}</p>
                <p v-if="cap.description" class="text-xs text-muted-foreground mt-0.5">{{ cap.description }}</p>
              </td>
              <td
                v-for="role in roleColumns"
                :key="role.key"
                class="px-3 py-2.5 text-center"
              >
                <span v-if="cap.roles?.[role.key]" class="text-green-600">✓</span>
                <span v-else class="text-muted-foreground/40">✕</span>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from "vue-i18n"
import type { CapabilityModuleGroup, MatrixRoleColumn } from "@/types/operational_roles"

const { t } = useI18n()

defineProps<{
  capability_matrix: CapabilityModuleGroup[]
  roleColumns: MatrixRoleColumn[]
}>()
</script>
