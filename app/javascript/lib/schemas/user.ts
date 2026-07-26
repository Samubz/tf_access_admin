import { z } from 'zod'

export const userValidationKeys = {
  name_required: 'admin.users.validations.name_required',
  dni_required: 'admin.users.validations.dni_required',
  email_invalid: 'admin.users.validations.email_invalid',
  password_min: 'admin.users.validations.password_min',
  password_confirmation_min: 'admin.users.validations.password_confirmation_min',
  password_mismatch: 'admin.users.validations.password_mismatch',
  role_required: 'admin.users.validations.role_required',
  language_required: 'admin.users.validations.language_required',
  password_lowercase: 'admin.users.validations.password_lowercase',
  password_uppercase: 'admin.users.validations.password_uppercase',
  password_number: 'admin.users.validations.password_number',
  password_symbol: 'admin.users.validations.password_symbol',
  reset_password_token_required: 'admin.users.validations.reset_password_token_required',
  email_required: 'admin.users.validations.email_required',
  password_required: 'admin.users.validations.password_required',
} as const

export const passwordSchema = z.string().min(8, userValidationKeys.password_min)
.regex(/[a-z]/, { message: userValidationKeys.password_lowercase })
.regex(/[A-Z]/, { message: userValidationKeys.password_uppercase })
.regex(/[0-9]/, { message: userValidationKeys.password_number })
.regex(/[$%@.\-_]/, { message: userValidationKeys.password_symbol });

export const passwordConfirmationSchema = z.string().min(8, userValidationKeys.password_confirmation_min);

const userBaseSchema = z.object({
  name: z.string().min(1, userValidationKeys.name_required),
  dni: z.string().min(1, userValidationKeys.dni_required),
  email: z.string().email(userValidationKeys.email_invalid),
  password: passwordSchema,
  password_confirmation: passwordConfirmationSchema,
  role: z.string().min(1, userValidationKeys.role_required),
  language: z.string().min(1, userValidationKeys.language_required),
});

export const userSchema = userBaseSchema
.refine((data) => data.password === data.password_confirmation, {
  message: userValidationKeys.password_mismatch,
  path: ['password_confirmation'],
})

export const userEditSchema = userBaseSchema
  .omit({ password: true, password_confirmation: true })
  .extend({
    password: z.union([passwordSchema, z.literal('')]),
    password_confirmation: z.union([passwordConfirmationSchema, z.literal('')]),
  })
  .refine(
    (data) =>
      (!data.password && !data.password_confirmation) ||
      data.password === data.password_confirmation,
    { message: userValidationKeys.password_mismatch, path: ['password_confirmation'] }
  );

export type UserSchema = z.infer<typeof userSchema>;
export type UserEditSchema = z.infer<typeof userEditSchema>;