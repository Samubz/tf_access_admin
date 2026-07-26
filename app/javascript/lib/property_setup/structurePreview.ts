export type StructureFormatLevel = {
  section_type: string
  label_key: string
  suffix_type: 'letter' | 'number'
}

export type PropertyStructureFormat = {
  levels: StructureFormatLevel[]
  units_in: string
}

/** Generic quick-structure params emitted by the dynamic form, sent to the
 * format-aware backend preview/commit. */
export type QuickStructureFormParams = {
  level_1_count: number
  level_2_count: number
  level_1_prefix: string
  level_2_prefix: string
  skip_top_level: boolean
}

/** Flat node returned by the backend structure_preview endpoint. */
export type PreviewNode = {
  id: string
  parent_id?: string
  name: string
  section_type: string
  depth: number
}

/** Persisted unit row embedded in a leaf node by the backend tree (manual mode,
 * step 2/4 previews). Step 3 automatic mode instead injects plain projected
 * identifier strings client-side (see `unitsPreview.ts`). */
export type StructureTreeUnit = {
  id: string
  identifier: string
  display_name?: string | null
  unit_type?: string
  area_m2?: number | null
}

export type StructureTreeNode = {
  id: string
  name: string
  section_type?: string
  position?: number
  children?: StructureTreeNode[]
  /** Projected identifier strings (automatic preview) or persisted unit rows
   * (backend tree) injected into leaf nodes. */
  units?: string[] | StructureTreeUnit[]
}

export type TreeChildDisplayItem =
  | { kind: 'child'; node: StructureTreeNode }
  | { kind: 'ellipsis' }

export function displayTreeChildren(children: StructureTreeNode[] = []): TreeChildDisplayItem[] {
  if (children.length <= 4) {
    return children.map((node) => ({ kind: 'child', node }))
  }

  return [
    { kind: 'child', node: children[0] },
    { kind: 'child', node: children[1] },
    { kind: 'ellipsis' },
    { kind: 'child', node: children[children.length - 1] },
  ]
}

export type SuffixType = 'letter' | 'number'

/** Mirror of `Properties::Setup::SectionNameSequence` (Ruby). Single source of
 * truth for "prefix + suffix" naming, shared by the quick engine and the manual
 * builder modal's live "De creación" preview. `index` is zero-based:
 * index 0 → "A" / "1". Keep in sync with the Ruby helper. */
export function sectionName(prefix: string, suffixType: SuffixType, index: number): string {
  return `${prefix} ${sectionNameSuffix(suffixType, index)}`.trim()
}

export function sectionNames(prefix: string, suffixType: SuffixType, count: number): string[] {
  return Array.from({ length: Math.max(count, 0) }, (_, index) =>
    sectionName(prefix, suffixType, index),
  )
}

export const SECTION_NAME_LETTER_MAX_INDEX = 25
export const SECTION_NAME_NUMBER_MAX_INDEX = 999

/** Mirror of `PropertySection.normalize_name` (Ruby). Keep in sync. */
export function normalizeSectionName(name: string): string {
  return name.trim().replace(/\s+/g, ' ').normalize('NFKC').toLowerCase()
}

export type SectionNameAllocation = {
  names: string[]
  skipped: string[]
  insufficient: boolean
}

/** Allocates the next +count+ free sequential names, skipping taken siblings
 * by full normalized name comparison (never parses existing suffixes). */
export function allocateSectionNames(
  prefix: string,
  suffixType: SuffixType,
  count: number,
  takenNormalizedNames: Iterable<string>,
): SectionNameAllocation {
  const taken = new Set(takenNormalizedNames)
  const names: string[] = []
  const skipped: string[] = []
  const limit = suffixType === 'letter' ? SECTION_NAME_LETTER_MAX_INDEX : SECTION_NAME_NUMBER_MAX_INDEX
  let index = 0

  while (names.length < count && index <= limit) {
    const candidate = sectionName(prefix, suffixType, index)
    const normalized = normalizeSectionName(candidate)
    if (normalized && taken.has(normalized)) {
      skipped.push(candidate)
    } else if (normalized) {
      names.push(candidate)
    }
    index += 1
  }

  return { names, skipped, insufficient: names.length < count }
}

export function sectionNameSuffix(suffixType: SuffixType, index: number): string {
  return suffixType === 'letter' ? String.fromCharCode('A'.charCodeAt(0) + index) : String(index + 1)
}

/** Builds a nested tree from the flat preview nodes returned by the backend. */
export function buildTreeFromPreviewNodes(nodes: PreviewNode[]): StructureTreeNode[] {
  const byId = new Map<string, StructureTreeNode>()
  const roots: StructureTreeNode[] = []

  for (const node of nodes) {
    byId.set(node.id, { id: node.id, name: node.name, children: [] })
  }

  for (const node of nodes) {
    const current = byId.get(node.id)!
    const parent = node.parent_id ? byId.get(node.parent_id) : undefined
    if (parent) {
      parent.children!.push(current)
    } else {
      roots.push(current)
    }
  }

  return roots
}
