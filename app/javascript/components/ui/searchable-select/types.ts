export type SearchableSelectOption = {
  value: string
  label: string
  description?: string
}

export type SearchableSelectLoadResult = {
  options: SearchableSelectOption[]
  hasMore: boolean
}

export type SearchableSelectLoader = (params: {
  query: string
  page: number
}) => Promise<SearchableSelectLoadResult>
