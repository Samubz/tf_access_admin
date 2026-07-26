import type { BreadcrumbItem } from '@/types/layout'
import { admin_home_index_path, admin_residential_properties_path } from '@/routes'
import { useI18n } from 'vue-i18n'

export function getResidentialPropertiesBreadcrumbs(t: ReturnType<typeof useI18n>['t']): BreadcrumbItem[] {
  return [
    {
      label: t('admin.home.title'),
      href: admin_home_index_path(),
    },
    {
      label: t('admin.residential_properties.index.title'),
      href: admin_residential_properties_path(),
    },
  ]
}

export function getResidentialPropertyDetailBreadcrumbs(
  t: ReturnType<typeof useI18n>['t'],
  propertyName: string,
): BreadcrumbItem[] {
  return [
    ...getResidentialPropertiesBreadcrumbs(t),
    {
      label: propertyName,
    },
  ]
}
