export type SuffixType = 'letter' | 'number'

export const UNIT_IDENTIFIER_LETTER_MAX_INDEX = 25
export const UNIT_IDENTIFIER_NUMBER_MAX_INDEX = 999
const MAX_SLUG_LENGTH = 32

/** Mirror of `DomainCodes::Slug` (Ruby) used by `Units::NormalizeIdentifier`.
 * Approximates Rails' `parameterize`: transliterate accents to ASCII, downcase,
 * collapse any run of non `[a-z0-9]` to a single hyphen, trim, cap length. */
export function normalizeUnitIdentifier(value: string): string {
  const slug = value
    .normalize('NFKD')
    .replace(new RegExp('[' + String.fromCharCode(0x300) + '-' + String.fromCharCode(0x36f) + ']', 'g'), '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')

  return slug.length <= MAX_SLUG_LENGTH ? slug : slug.slice(0, MAX_SLUG_LENGTH).replace(/-+$/, '')
}

function unitIdentifierSuffix(suffixType: SuffixType, index: number): string {
  return suffixType === 'letter' ? String.fromCharCode('A'.charCodeAt(0) + index) : String(index + 1)
}

export function unitIdentifierCandidate(prefix: string, suffixType: SuffixType, index: number): string {
  return `${prefix} ${unitIdentifierSuffix(suffixType, index)}`.trim()
}

export type UnitIdentifierAllocation = {
  identifiers: string[]
  skipped: string[]
  insufficient: boolean
}

/** Mirror of `Units::IdentifierSequence.available_identifiers` (Ruby). Allocates
 * the next +count+ free sequential identifiers, skipping siblings already taken
 * in the target section (by full normalized identifier comparison). */
export function allocateUnitIdentifiers(
  prefix: string,
  suffixType: SuffixType,
  count: number,
  takenNormalizedIdentifiers: Iterable<string>,
): UnitIdentifierAllocation {
  const taken = new Set(takenNormalizedIdentifiers)
  const identifiers: string[] = []
  const skipped: string[] = []
  const limit = suffixType === 'letter' ? UNIT_IDENTIFIER_LETTER_MAX_INDEX : UNIT_IDENTIFIER_NUMBER_MAX_INDEX
  let index = 0

  while (identifiers.length < count && index <= limit) {
    const candidate = unitIdentifierCandidate(prefix, suffixType, index)
    const normalized = normalizeUnitIdentifier(candidate)
    if (normalized && taken.has(normalized)) {
      skipped.push(candidate)
    } else if (normalized) {
      identifiers.push(candidate)
    }
    index += 1
  }

  return { identifiers, skipped, insufficient: identifiers.length < count }
}
