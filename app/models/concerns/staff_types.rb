# frozen_string_literal: true

# Allowed +staff_assignments.staff_type+ values (string-backed).
#
# Persisted on +StaffAssignment+ as the operational staff role per property.
# Maps to contextual staff badges in +People::ContextualRoles+ when staff flows
# are integrated (+concierge+, +property_admin+, +cleaning_staff+).
module StaffTypes
  CONCIERGE     = "concierge"
  SECURITY      = "security"
  CLEANING      = "cleaning"
  MANAGER       = "manager"
  MAINTENANCE   = "maintenance"
  OTHER         = "other"

  ALL = [ CONCIERGE, SECURITY, CLEANING, MANAGER, MAINTENANCE, OTHER ].freeze

  # Normalized operational role aliases. These string values may appear in legacy
  # data persisted before the canonical ALL types were enforced. The mapper in
  # Authorization::StaffRoleMapper normalizes them to their canonical operational
  # role. They are intentionally excluded from ALL (and therefore from the
  # inclusion validation) to prevent new records from using them.
  PROPERTY_ADMIN = "property_admin"
  CLEANING_STAFF = "cleaning_staff"
  INTERNAL_STAFF = "internal_staff"
end
