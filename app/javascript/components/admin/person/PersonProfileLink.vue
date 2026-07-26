<template>
  <Link
    :href="admin_person_path(personId)"
    class="inline-flex items-center gap-3 font-medium text-primary hover:underline"
  >
    <slot />
  </Link>
</template>

<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { admin_person_path } from '@/routes'

defineProps<{
  personId: string
}>()
</script>
