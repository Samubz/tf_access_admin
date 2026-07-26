<template>
  <div class="flex min-h-screen items-center justify-center px-4 py-12">
    <Card class="w-full max-w-md text-center">
      <CardHeader>
        <CardTitle>{{ t('onboarding.invalid.title') }}</CardTitle>
        <CardDescription>{{ t('onboarding.invalid.description') }}</CardDescription>
      </CardHeader>
      <CardFooter class="justify-center">
        <Button type="button" as="a" :href="new_user_session_path()">
          {{ t('onboarding.invalid.sign_in') }}
        </Button>
      </CardFooter>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Button } from '@/components/ui/button'
import { Card, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { new_user_session_path } from '@/routes'

const { t } = useI18n()
</script>
