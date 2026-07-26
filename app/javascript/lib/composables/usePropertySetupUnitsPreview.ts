import { computed, ref, watch, type Ref } from 'vue'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'
import {
  buildUnitsPreviewFromTree,
  countUnitsPreviewGroups,
  type UnitsPreviewGroup,
  type UnitsPreviewParams,
} from '@/lib/property_setup/unitsPreview'
import type { StructureTreeNode } from '@/lib/property_setup/structurePreview'

export type { UnitsPreviewParams, UnitsPreviewGroup }

export type UnitsPreviewRow = {
  tower: string | null
  floor: string | null
  identifier: string
}

export function groupUnitsPreviewRows(rows: UnitsPreviewRow[]): UnitsPreviewGroup[] {
  const groups = new Map<string, string[]>()

  for (const row of rows) {
    const label =
      row.tower && row.floor
        ? `${row.tower} - ${row.floor}`
        : row.floor || '—'
    const current = groups.get(label) ?? []
    current.push(row.identifier)
    groups.set(label, current)
  }

  return [...groups.entries()].map(([label, identifiers]) => ({
    label,
    identifiers: identifiers.join(', '),
  }))
}

const COMBINATIONS_PER_PAGE = 3
const FETCH_PER_PAGE = 500

export function usePropertySetupUnitsPreview(
  propertyId: Ref<string | undefined>,
  params: Ref<UnitsPreviewParams>,
  enabled: Ref<boolean>,
  structureTree: Ref<StructureTreeNode[]>,
) {
  const { railsFetchJson } = useRailsFetch()
  const loading = ref(false)
  const apiTotalUnits = ref(0)
  const apiGroups = ref<UnitsPreviewGroup[]>([])
  const combinationPage = ref(1)

  const clientGroups = computed(() => {
    if (!enabled.value) return []
    return buildUnitsPreviewFromTree(structureTree.value, params.value)
  })

  const groups = computed(() => {
    if (apiGroups.value.length > 0) return apiGroups.value
    return clientGroups.value
  })

  const totalUnits = computed(() => {
    if (apiTotalUnits.value > 0) return apiTotalUnits.value
    return countUnitsPreviewGroups(clientGroups.value)
  })

  async function loadPreview() {
    if (!propertyId.value || !enabled.value) {
      apiGroups.value = []
      apiTotalUnits.value = 0
      combinationPage.value = 1
      return
    }

    loading.value = true
    const search = new URLSearchParams({
      page: '1',
      per_page: String(FETCH_PER_PAGE),
      unit_type: params.value.unit_type ?? 'apartment',
      identifier_format: params.value.identifier_format ?? 'floor_sequential',
      units_per_leaf: String(params.value.units_per_leaf ?? 4),
    })

    const { res, data } = await railsFetchJson<{
      rows: UnitsPreviewRow[]
      total_units: number
    }>(
      'GET',
      `/admin/property_setup/wizard/${propertyId.value}/units_preview?${search.toString()}`,
    )

    if (res.ok) {
      apiTotalUnits.value = data.total_units ?? 0
      apiGroups.value = groupUnitsPreviewRows(data.rows ?? [])
      combinationPage.value = 1
    }

    loading.value = false
  }

  watch([propertyId, params, enabled, structureTree], () => {
    void loadPreview()
  }, { immediate: true, deep: true })

  watch([params, structureTree], () => {
    combinationPage.value = 1
  }, { deep: true })

  const totalCombinations = computed(() => groups.value.length)
  const totalCombinationPages = computed(() =>
    Math.max(1, Math.ceil(totalCombinations.value / COMBINATIONS_PER_PAGE)),
  )

  const paginatedGroups = computed(() => {
    const offset = (combinationPage.value - 1) * COMBINATIONS_PER_PAGE
    return groups.value.slice(offset, offset + COMBINATIONS_PER_PAGE)
  })

  function nextPage() {
    if (combinationPage.value < totalCombinationPages.value) combinationPage.value += 1
  }

  function prevPage() {
    if (combinationPage.value > 1) combinationPage.value -= 1
  }

  return {
    loading,
    totalUnits,
    paginatedGroups,
    totalCombinations,
    combinationPage,
    totalCombinationPages,
    nextPage,
    prevPage,
    loadPreview,
  }
}
