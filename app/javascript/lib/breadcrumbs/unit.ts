import type { BreadcrumbItem } from '@/types/layout'
import {
  admin_home_index_path,
  admin_residential_properties_path,
  admin_property_setup_wizard_path,
} from '@/routes'
import type { useI18n } from 'vue-i18n'

export function getUnitShowBreadcrumbs(
  t: ReturnType<typeof useI18n>['t'],
  residentialPropertyId: string,
  propertyName: string,
  locationPath: string[],
  unitTitle: string
): BreadcrumbItem[] {
  const items: BreadcrumbItem[] = [
    { label: t('admin.home.title'), href: admin_home_index_path() },
    { label: t('admin.residential_properties.index.title'), href: admin_residential_properties_path() },
    { label: propertyName, href: admin_property_setup_wizard_path(residentialPropertyId) },
  ]

  locationPath.forEach((segment) => {
    items.push({ label: segment })
  })

  items.push({ label: unitTitle })

  return items
}
