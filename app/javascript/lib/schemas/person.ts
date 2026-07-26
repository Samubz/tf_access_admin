import { z } from 'zod'

export const personValidationKeys = {
  display_name_required: 'admin.people.validations.display_name_required',
  person_type_required: 'admin.people.validations.person_type_required',
  status_required: 'admin.people.validations.status_required',
  email_invalid: 'admin.people.validations.email_invalid',
} as const

export const personSchema = z
  .object({
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  document_number: z.string().optional(),
  email: z.union([z.string().email(personValidationKeys.email_invalid), z.literal('')]).optional(),
  phone: z.string().optional(),
  birthdate: z.string().optional(),
  send_invitation: z.boolean().optional(),
})

export type PersonSchema = z.infer<typeof personSchema>
