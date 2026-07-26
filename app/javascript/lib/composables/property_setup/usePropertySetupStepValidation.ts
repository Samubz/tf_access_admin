import { ref } from 'vue'
import {
  mapPropertySetupZodErrors,
  propertySetupStep1Schema,
  validatePropertySetupStep2,
  validatePropertySetupStep3,
  type PropertySetupStep1Values,
  type PropertySetupStep2Values,
  type PropertySetupStep3Values,
} from '@/lib/schemas/property_setup'

export function usePropertySetupStepValidation() {
  const fieldErrors = ref<Record<string, string>>({})

  function clearFieldErrors() {
    fieldErrors.value = {}
  }

  function setFieldErrors(errors: Record<string, string>) {
    fieldErrors.value = errors
  }

  function validateStep1(values: PropertySetupStep1Values): boolean {
    const result = propertySetupStep1Schema.safeParse(values)
    if (result.success) {
      clearFieldErrors()
      return true
    }

    setFieldErrors(mapPropertySetupZodErrors(result.error))
    return false
  }

  function validateStep2(values: PropertySetupStep2Values, sectionsCount: number): boolean {
    const errors = validatePropertySetupStep2(values, { sectionsCount })
    if (Object.keys(errors).length === 0) {
      clearFieldErrors()
      return true
    }

    setFieldErrors(errors)
    return false
  }

  function validateStep3(values: PropertySetupStep3Values): boolean {
    const errors = validatePropertySetupStep3(values)
    if (Object.keys(errors).length === 0) {
      clearFieldErrors()
      return true
    }

    setFieldErrors(errors)
    return false
  }

  function fieldError(path: string): string | undefined {
    return fieldErrors.value[path]
  }

  return {
    fieldErrors,
    clearFieldErrors,
    setFieldErrors,
    validateStep1,
    validateStep2,
    validateStep3,
    fieldError,
  }
}
