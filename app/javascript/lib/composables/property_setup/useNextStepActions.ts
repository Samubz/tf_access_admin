import { computed, type ComputedRef } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, Search, Settings2, UserRound, Users } from 'lucide-vue-next'

export type NextStepAction = {
  key: string
  recommended: boolean
  icon: unknown
  title: string
  description: string
  buttonLabel: string
  href?: string
  disabled: boolean
}

// Shared next-action definitions for the wizard step 5 completion screen and
// the property detail page's "Próximos pasos recomendados" section, so both
// surfaces stay in sync on labels, hrefs, and authorization gating
// (add-property-detail-view).
export function useNextStepActions(
  nextActions: ComputedRef<string[]> | string[],
  propertyId: ComputedRef<string | undefined> | string | undefined,
) {
  const { t } = useI18n()

  const actionsList = computed(() => (Array.isArray(nextActions) ? nextActions : nextActions.value))
  const id = computed(() => (typeof propertyId === 'object' ? propertyId?.value : propertyId))

  function showAction(action: string) {
    return actionsList.value.includes(action)
  }

  const nextStepActions = computed<NextStepAction[]>(() => [
    {
      key: 'property_detail',
      recommended: true,
      icon: Search,
      title: t('admin.property_setup.step5.completed.next_steps.property_detail.title'),
      description: t('admin.property_setup.step5.completed.next_steps.property_detail.description'),
      buttonLabel: t('admin.property_setup.step5.completed.next_steps.property_detail.action'),
      href: id.value && showAction('property_detail')
        ? `/admin/residential_properties/${id.value}`
        : undefined,
      disabled: !showAction('property_detail'),
    },
    {
      key: 'reopen_setup',
      recommended: false,
      icon: Settings2,
      title: t('admin.property_setup.step5.completed.next_steps.reopen_setup.title'),
      description: t('admin.property_setup.step5.completed.next_steps.reopen_setup.description'),
      buttonLabel: t('admin.property_setup.step5.completed.next_steps.reopen_setup.action'),
      href: id.value && showAction('reopen_setup')
        ? `/admin/property_setup/wizard/${id.value}`
        : undefined,
      disabled: !showAction('reopen_setup'),
    },
    {
      key: 'manage_units',
      recommended: false,
      icon: Building2,
      title: t('admin.property_setup.step5.completed.next_steps.manage_units.title'),
      description: t('admin.property_setup.step5.completed.next_steps.manage_units.description'),
      buttonLabel: t('admin.property_setup.step5.completed.next_steps.manage_units.action'),
      // No dedicated units-management page exists yet; `/units` is a JSON-only
      // API action (add-property-detail-view), so this action has no browsable
      // destination until one is built.
      href: undefined,
      disabled: !showAction('manage_units'),
    },
    {
      key: 'import_owners',
      recommended: false,
      icon: Users,
      title: t('admin.property_setup.step5.completed.next_steps.import_owners.title'),
      description: t('admin.property_setup.step5.completed.next_steps.import_owners.description'),
      buttonLabel: t('admin.property_setup.step5.completed.next_steps.import_owners.action'),
      href: undefined,
      disabled: !showAction('import_owners'),
    },
    {
      key: 'configure_residents',
      recommended: false,
      icon: UserRound,
      title: t('admin.property_setup.step5.completed.next_steps.configure_residents.title'),
      description: t('admin.property_setup.step5.completed.next_steps.configure_residents.description'),
      buttonLabel: t('admin.property_setup.step5.completed.next_steps.configure_residents.action'),
      href: undefined,
      disabled: !showAction('configure_residents'),
    },
  ])

  return { nextStepActions }
}
