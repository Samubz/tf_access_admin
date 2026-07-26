<template>
  <div>
    <Header :itemsBreadcrumb="itemsBreadcrumb" :title="t('admin.people.index.title')" />
    <AdminDataTable :columns="columns" :data="people">
      <template #actions-table>
        <div class="w-full flex items-center justify-between gap-2">
          <div class="w-full md:w-1/2 flex gap-2">
            <Input
              type="search"
              :placeholder="t('admin.people.index.input.search.placeholder')"
              v-model="search"
              @search="onSearchClear"
            />
            <Button variant="outline" @click="triggerSearch">
              <SearchIcon class="w-4 h-4" />
              {{ t('common.actions.search') }}
            </Button>
          </div>
          <div class="flex shrink-0 gap-2">
            <Button variant="outline" @click="showBulkImportDrawer = true">
              <UploadIcon class="w-4 h-4" />
              {{ t('admin.people.index.actions.bulk_import') }}
            </Button>
            <Link :href="new_admin_person_path()">
              <Button>
                <PlusIcon class="w-4 h-4" />
                {{ t('admin.people.index.actions.create') }}
              </Button>
            </Link>
          </div>
        </div>
      </template>
      <template #actions="{ row }">
        <ListItem as="link" :href="admin_person_path(row.id as string)">
          <span class="flex items-center gap-2">
            <EyeIcon class="w-4 h-4" />
            {{ t('admin.people.index.actions.view_profile') }}
          </span>
        </ListItem>
        <ListItem as="link" :href="edit_admin_person_path(row.id as string)">
          <span class="flex items-center gap-2">
            <PencilIcon class="w-4 h-4" />
            {{ t('common.actions.edit') }}
          </span>
        </ListItem>
        <ListItem
          v-if="row.invitation_status === 'not_invited' && row.email"
          as="confirm"
          :onClick="() => invitePerson(row.id as string)"
          :confirmTitle="t('admin.people.index.actions.invite')"
          :confirmDescription="
            t('admin.people.index.actions.invite_description', { name: row.display_name })
          "
        >
          <span class="flex items-center gap-2">
            <SendIcon class="w-4 h-4" />
            {{ t('admin.people.index.actions.invite') }}
          </span>
        </ListItem>
        <ListItem
          v-else-if="row.invitation_status === 'pending' && row.pending_onboarding_request_id"
          as="confirm"
          :onClick="() => revokeInvitation(row.pending_onboarding_request_id as string)"
          :confirmTitle="t('admin.people.index.actions.revoke_invite')"
          :confirmDescription="
            t('admin.people.index.actions.revoke_invite_description', { name: row.display_name })
          "
        >
          <span class="flex items-center gap-2 text-destructive">
            <BanIcon class="w-4 h-4" />
            {{ t('admin.people.index.actions.revoke_invite') }}
          </span>
        </ListItem>
        <ListItem
          as="confirm"
          :onClick="() => deletePerson(row.id as string)"
          :confirmTitle="t('admin.people.index.actions.delete')"
          :confirmDescription="
            t('admin.people.index.actions.delete_description', { name: row.display_name })
          "
        >
          <span class="flex items-center gap-2">
            <TrashIcon class="w-4 h-4" />
            {{ t('common.actions.delete') }}
          </span>
        </ListItem>
      </template>
      <template v-if="paginationMeta" #footer>
        <DataTablePagination
          :current-page="currentPage"
          :total-pages="totalPages"
          :total-items="totalItems"
          :items-per-page="itemsPerPage"
          :items-per-page-options="itemsPerPageOptions"
          :on-page-change="handlePageChange"
          :on-items-per-page-change="handleItemsPerPageChange"
        />
      </template>
    </AdminDataTable>

    <BulkPeopleImportDrawer v-model:open="showBulkImportDrawer" />
  </div>
</template>

<script setup lang="ts">
import { h, watch, onMounted, computed, ref } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import AdminDataTable from '@/components/admin/table/index.vue'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import { useTable } from '@/lib/composables/useTable'
import { useI18n } from 'vue-i18n'
import type { ColumnDef } from '@/types/table'
import { Button } from '@/components/ui/button'
import { PlusIcon, SearchIcon, PencilIcon, TrashIcon, EyeIcon, UploadIcon, SendIcon, BanIcon } from 'lucide-vue-next'
import { Input } from '@/components/ui/input'
import {
  new_admin_person_path,
  admin_person_path,
  edit_admin_person_path,
  invite_admin_person_path,
  revoke_admin_onboarding_request_path,
} from '@/routes'
import ListItem from '@/components/custom/list/ListItem.vue'
import Header from '@/components/admin/layout/Header.vue'
import PersonContextualRoleBadges from '@/components/admin/person/PersonContextualRoleBadges.vue'
import BulkPeopleImportDrawer from '@/components/admin/bulk_people/BulkPeopleImportDrawer.vue'
import type { Person } from '@/types/person'
import { toast } from 'vue-sonner'
import { getPeopleBreadcrumbs } from '@/lib/breadcrumbs/person'

const { t } = useI18n()

const showBulkImportDrawer = ref(false)

watch(showBulkImportDrawer, (isOpen, wasOpen) => {
  if (!isOpen && wasOpen) {
    router.reload({ only: ['people', 'pagination'] })
  }
})

const props = defineProps<{
  people: Person[]
  pagination?: {
    current_page: number
    per_page: number
    total_pages: number
    total_count: number
  }
  errors?: Record<string, string[]>
}>()

const fetchData = (search: string, page: number, itemsPerPage: number) => {
  router.get(
    '/admin/people',
    { page, per_page: itemsPerPage, q: { display_name_or_first_name_or_last_name_cont: search } },
    { preserveState: true }
  )
}

const itemsBreadcrumb = computed(() => getPeopleBreadcrumbs(t))
const {
  currentPage,
  totalPages,
  totalItems,
  itemsPerPage,
  itemsPerPageOptions,
  search,
  handlePageChange,
  handleItemsPerPageChange,
  setPagination,
  triggerSearch,
} = useTable(fetchData, {
  skipInitialFetch: true,
  initialPagination: props.pagination,
})
const paginationMeta = props.pagination

watch(
  () => props.pagination,
  (meta) => {
    if (meta) setPagination(meta)
  },
  { immediate: false }
)

onMounted(() => {
  const baseError = props.errors?.base?.[0]
  if (baseError) toast.error(t(baseError))
})

const columns: ColumnDef<Person, unknown>[] = [
  {
    accessorKey: 'display_name',
    header: () => t('admin.people.index.table.headers.display_name'),
    cell: ({ row }) => {
      const person = row.original
      if (!person.id) return h('span', person.display_name)

      return h(
        Link,
        {
          href: admin_person_path(person.id),
          class: 'font-medium text-primary hover:underline',
        },
        () => person.display_name,
      )
    },
  },
  {
    accessorKey: 'contextual_roles',
    header: () => t('admin.people.index.table.headers.contextual_roles'),
    cell: ({ row }) =>
      h(PersonContextualRoleBadges, {
        roles: row.original.contextual_roles ?? [],
      }),
  },
  {
    accessorKey: 'document_number',
    header: () => t('admin.people.index.table.headers.document_number'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'email',
    header: () => t('admin.people.index.table.headers.email'),
    cell: ({ getValue }) => h('span', (getValue() as string) || '—'),
  },
  {
    accessorKey: 'status',
    header: () => t('admin.people.index.table.headers.status'),
    cell: ({ getValue }) => h('span', t(`admin.people.statuses.${getValue()}`)),
  },
  {
    accessorKey: 'unit_ownerships_count',
    header: () => t('admin.people.index.table.headers.unit_ownerships_count'),
    cell: ({ getValue }) => h('span', (getValue() as number).toString()),
  },
  {
    accessorKey: 'invitation_status',
    header: () => t('admin.people.index.table.headers.invitation_status'),
    cell: ({ row }) => {
      const status = row.original.invitation_status
      if (!status) return h('span', '—')

      const label = t(`admin.people.index.invitation_statuses.${status}`)
      if (status === 'not_invited' && !row.original.email) {
        return h('span', [
          label,
          h('span', { class: 'block text-xs text-muted-foreground' }, t('admin.people.index.invitation_statuses.no_email_hint')),
        ])
      }
      return h('span', label)
    },
  },
]

const deletePerson = (id: string) => {
  router.delete(admin_person_path(id), {
    onSuccess: () => toast.success(t('admin.people.index.actions.delete_success')),
    onError: () => toast.error(t('admin.people.index.actions.delete_error')),
  })
}

const invitePerson = (id: string) => {
  // The controller redirects here even when the invite fails (AlreadyInvited),
  // sharing the error via `errors.base` (shown by the onMounted handler above)
  // rather than a validation re-render — so onSuccess always fires and must
  // not unconditionally claim success (same reasoning as onboarding invite
  // conflicts). The updated "Invitation sent" status in the table is the
  // real success signal.
  router.post(invite_admin_person_path(id), undefined, {
    preserveScroll: true,
    onError: () => toast.error(t('admin.people.index.actions.invite_error')),
  })
}

const revokeInvitation = (onboardingRequestId: string) => {
  router.post(revoke_admin_onboarding_request_path(onboardingRequestId), undefined, {
    preserveScroll: true,
    onSuccess: () => toast.success(t('admin.people.index.actions.revoke_invite_success')),
    onError: () => toast.error(t('admin.people.index.actions.revoke_invite_error')),
  })
}

const onSearchClear = (e: Event) => {
  const target = e.target as HTMLInputElement
  if (target?.value === '') triggerSearch()
}
</script>
