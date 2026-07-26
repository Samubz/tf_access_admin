export type ValidityState = 'current' | 'finished' | 'pending' | 'inactive'

export function validityStateClass(state: ValidityState) {
  if (state === 'current') return 'text-green-600'
  if (state === 'finished') return 'text-destructive'
  return 'text-muted-foreground'
}

export function formatValidityDate(value: string | null | undefined, locale: string) {
  if (!value) return '—'

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(date)
}

export function formatValidityRange(
  startsAt: string,
  endsAt: string | null | undefined,
  locale: string,
  openEndedLabel: string,
) {
  const start = formatValidityDate(startsAt, locale)
  const end = endsAt ? formatValidityDate(endsAt, locale) : openEndedLabel

  return `${start} – ${end}`
}
