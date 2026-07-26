import type { StructureTreeNode } from '@/lib/property_setup/structurePreview'

export type UnitsPreviewParams = {
  unit_type?: string
  identifier_format?: string
  units_per_leaf?: number
}

export type UnitsPreviewGroup = {
  label: string
  identifiers: string
}

export function unitIdentifiers(node: StructureTreeNode, params: UnitsPreviewParams): string[] {
  const quantity = Math.max(params.units_per_leaf ?? 4, 1)
  const format = params.identifier_format ?? 'floor_sequential'
  const base = leafBase(node)
  return Array.from({ length: quantity }, (_, index) => {
    if (format === 'block_sequential') return `B${base + index + 1}`
    if (format === 'sequential') return String(index + 1)
    // floor_sequential (default)
    return String(base + index + 1)
  })
}

/** Deep-clones the section tree and injects projected unit identifiers into each
 * leaf node. Used to render the step-3 client preview. */
export function buildTreeWithUnits(
  tree: StructureTreeNode[],
  params: UnitsPreviewParams,
): StructureTreeNode[] {
  function inject(node: StructureTreeNode): StructureTreeNode {
    const children = node.children ?? []
    if (children.length > 0) {
      return { ...node, children: children.map(inject) }
    }
    return { ...node, units: unitIdentifiers(node, params) }
  }
  return tree.map(inject)
}

/** Position-based base shared by `floor_sequential` and `block_sequential`
 * (matches the backend `UnitGenerationPlan#position_base`: `position * 100`,
 * starting at 100 → first identifier 101 / B101 for position 1). Falls back to
 * the trailing digits of the leaf name when no explicit position is set. */
function leafBase(leaf: StructureTreeNode): number {
  if (typeof leaf.position === 'number' && leaf.position > 0) {
    return leaf.position * 100
  }

  const match = leaf.name.match(/(\d+)\s*$/)
  return (match ? Number.parseInt(match[1], 10) : 1) * 100
}

function identifiersForFloor(floor: StructureTreeNode, params: UnitsPreviewParams): string {
  return unitIdentifiers(floor, params).join(', ')
}

export function buildUnitsPreviewFromTree(
  tree: StructureTreeNode[],
  params: UnitsPreviewParams,
): UnitsPreviewGroup[] {
  const groups: UnitsPreviewGroup[] = []

  for (const tower of tree) {
    const floors = tower.children ?? []
    if (floors.length > 0) {
      for (const floor of floors) {
        groups.push({
          label: `${tower.name} - ${floor.name}`,
          identifiers: identifiersForFloor(floor, params),
        })
      }
      continue
    }

    groups.push({
      label: tower.name,
      identifiers: identifiersForFloor(tower, params),
    })
  }

  return groups
}

export function countUnitsPreviewGroups(groups: UnitsPreviewGroup[]): number {
  return groups.reduce((total, group) => {
    if (!group.identifiers) return total
    return total + group.identifiers.split(',').map((part) => part.trim()).filter(Boolean).length
  }, 0)
}
