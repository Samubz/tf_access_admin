import type { BreadcrumbItem } from '@/types/layout'
import { admin_home_index_path, admin_people_path } from '@/routes'
import type { useI18n } from 'vue-i18n'

export function getPeopleBreadcrumbs(t: ReturnType<typeof useI18n>['t']): BreadcrumbItem[] {
  return [
    {
      label: t('admin.home.title'),
      href: admin_home_index_path(),
    },
    {
      label: t('admin.people.title'),
      href: admin_people_path(),
    },
  ]
}

export function getPersonShowBreadcrumbs(
  t: ReturnType<typeof useI18n>['t'],
  displayName: string,
): BreadcrumbItem[] {
  return [
    ...getPeopleBreadcrumbs(t),
    {
      label: displayName,
    },
  ]
}
