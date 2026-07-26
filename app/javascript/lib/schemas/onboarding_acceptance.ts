import { z } from 'zod'
import { passwordSchema, passwordConfirmationSchema, userValidationKeys } from '@/lib/schemas/user'

export const onboardingAcceptanceSchema = z
  .object({
    name: z.string().optional(),
    dni: z.string().optional(),
    password: passwordSchema,
    password_confirmation: passwordConfirmationSchema,
  })
  .refine((data) => data.password === data.password_confirmation, {
    message: userValidationKeys.password_mismatch,
    path: ['password_confirmation'],
  })

export type OnboardingAcceptanceSchema = z.infer<typeof onboardingAcceptanceSchema>
