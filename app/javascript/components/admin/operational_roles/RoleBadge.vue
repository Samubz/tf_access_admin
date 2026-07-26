<template>
  <Badge :class="badgeClass" variant="outline">{{ label }}</Badge>
</template>

<script setup lang="ts">
import { computed } from "vue"
import { Badge } from "@/components/ui/badge"

const props = defineProps<{
  roleKey?: string | null
  label: string
}>()

const badgeClass = computed(() => {
  switch (props.roleKey) {
    case "tenant_admin":
      return "bg-purple-100 text-purple-800 border-purple-200"
    case "content_manager":
      return "bg-indigo-100 text-indigo-800 border-indigo-200"
    case "property_admin":
      return "bg-blue-100 text-blue-800 border-blue-200"
    case "concierge":
      return "bg-orange-100 text-orange-800 border-orange-200"
    case "cleaning_staff":
      return "bg-yellow-100 text-yellow-800 border-yellow-200"
    case "internal_staff":
      return "bg-gray-100 text-gray-800 border-gray-200"
    default:
      return ""
  }
})
</script>
