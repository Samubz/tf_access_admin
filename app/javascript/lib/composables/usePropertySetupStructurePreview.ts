import { ref, watch, type Ref } from 'vue'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'
import type {
  PreviewNode,
  QuickStructureFormParams,
} from '@/lib/property_setup/structurePreview'

export type StructurePreviewCounts = {
  level_1: number
  level_2: number
  sections: number
}

const FETCH_PER_PAGE = 1000

const EMPTY_COUNTS: StructurePreviewCounts = { level_1: 0, level_2: 0, sections: 0 }

/**
 * Fetches the format-aware structure preview from the backend whenever the
 * generic quick-structure params change. The backend resolves the property's
 * format and returns the section nodes; the client no longer generates them.
 */
export function usePropertySetupStructurePreview(
  propertyId: Ref<string | undefined>,
  params: Ref<QuickStructureFormParams>,
  enabled: Ref<boolean>,
) {
  const { railsFetchJson } = useRailsFetch()
  const loading = ref(false)
  const nodes = ref<PreviewNode[]>([])
  const counts = ref<StructurePreviewCounts>({ ...EMPTY_COUNTS })

  async function loadPreview() {
    if (!propertyId.value || !enabled.value) {
      nodes.value = []
      counts.value = { ...EMPTY_COUNTS }
      return
    }

    loading.value = true
    const search = new URLSearchParams({
      page: '1',
      per_page: String(FETCH_PER_PAGE),
      level_1_count: String(params.value.level_1_count ?? 1),
      level_2_count: String(params.value.level_2_count ?? 1),
      level_1_prefix: params.value.level_1_prefix ?? '',
      level_2_prefix: params.value.level_2_prefix ?? '',
      skip_top_level: String(params.value.skip_top_level ?? false),
    })

    const { res, data } = await railsFetchJson<{
      nodes: PreviewNode[]
      counts: StructurePreviewCounts
    }>(
      'GET',
      `/admin/property_setup/wizard/${propertyId.value}/structure_preview?${search.toString()}`,
    )

    if (res.ok) {
      nodes.value = data.nodes ?? []
      counts.value = data.counts ?? { ...EMPTY_COUNTS }
    }

    loading.value = false
  }

  watch([propertyId, params, enabled], () => {
    void loadPreview()
  }, { immediate: true, deep: true })

  return { loading, nodes, counts, loadPreview }
}
