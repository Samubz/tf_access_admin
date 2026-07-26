<template>
  <div class="space-y-1">
    <p class="text-muted-foreground text-xs">{{ label }}</p>
    <p class="text-sm font-medium">{{ value }}</p>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  label: string
  value: string
}>()
</script>
