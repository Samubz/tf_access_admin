import type { PersonContextualRole } from '@/types/person_profile'

export type Person = {
  id?: string
  display_name: string
  first_name?: string
  last_name?: string
  person_type: string
  status: string
  document_type?: string
  document_number?: string
  email?: string
  phone?: string
  birthdate?: string | null
  user_id?: string | null
  user_name?: string | null
  user_email?: string | null
  role?: string
  tenant_role?: string
  contextual_roles?: PersonContextualRole[]
  invitation_status?: 'linked' | 'pending' | 'not_invited'
  pending_onboarding_request_id?: string | null
}
