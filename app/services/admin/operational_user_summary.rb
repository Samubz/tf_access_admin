# frozen_string_literal: true

module Admin
  # Read-model / value object for future user management UI rows.
  #
  # Populated from: +User+, its linked +Person+, organizational role,
  # active +StaffAssignment+ rows, and effective capability keys resolved
  # by +Authorization::Resolver+. No table backs this struct; it is
  # assembled on-the-fly from existing domain records.
  #
  # Used as the contract for a future admin users index (section 7 of
  # operational-roles-and-permissions OpenSpec). Services and serializers
  # that populate this struct must be scoped to the current tenant.
  #
  # Fields:
  #   user_id             — UUID of the +User+ record
  #   email               — login email address
  #   name                — display name from +User+
  #   person_id           — UUID of the linked +Person+ (nil if unlinked)
  #   organization_role   — effective org-level role key, e.g. "tenant_admin" or "client"
  #   managed_properties  — Array<Hash> [{ id:, name:, role: }] from active StaffAssignments
  #   staff_assignments_summary — Array<Hash> [{ residential_property_name:, role:, status: }]
  #   account_status      — user account status string ("active", "inactive", …)
  #   capability_keys     — Array<Symbol> effective capabilities in the current org context
  OperationalUserSummary = Struct.new(
    :user_id,
    :email,
    :name,
    :person_id,
    :organization_role,
    :managed_properties,
    :staff_assignments_summary,
    :account_status,
    :capability_keys,
    keyword_init: true
  )
end
