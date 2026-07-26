import type { InertiaErrors } from '@/types/globals'

export function firstInertiaError(
  errors: InertiaErrors,
): { field: string; message: string } | null {
  for (const [field, messages] of Object.entries(errors)) {
    const message = Array.isArray(messages) ? messages[0] : messages
    if (message) return { field, message: String(message) }
  }
  return null
}

/** Formats the first server error as "{field value}: {message}" when a value exists. */
export function formatFieldValueErrorToast(
  errors: InertiaErrors,
  fieldValues: Record<string, string | undefined>,
): string | null {
  const first = firstInertiaError(errors)
  if (!first) return null

  const { field, message } = first
  if (field === 'base') return message

  const value = fieldValues[field]?.trim()
  return value ? `${value}: ${message}` : message
}
