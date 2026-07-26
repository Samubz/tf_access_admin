# frozen_string_literal: true

# Authorization policy for +Visit+ records.
#
# Capability-to-action contract (implementation of OpenSpec visit-management §5):
#
#   index?      → manage_visits / view_visits (admin) or view_authorized_visits (concierge)
#   show?       → manage_visits / view_visits (full) or view_authorized_visits (restricted)
#   create?     → create_visits (resident/owner unit context) or manage_visits (admin)
#   update?     → manage_visits (admin only)
#   authorize?  → authorize_visits (resident/owner unit context) or manage_visits (admin)
#   cancel?     → manage_visits or authorize_visits, only while pending/authorized
#   check_in?   → register_visit_entry, scoped to the visit's residential_property
#   check_out?  → register_visit_exit, scoped to the visit's residential_property
#
# Concierge (operational) actors MUST NOT create, update, authorize or cancel
# visits in the MVP (§5.6); they only hold view_authorized_visits plus the
# operational register_visit_entry/register_visit_exit capabilities. Check-in
# and check-out stay out of administration unless the actor explicitly holds the
# operational capability (§5.9); state validity is enforced by the AASM
# transitions, not by the policy boolean.
#
# Detail granularity (§5.7):
#   - full_detail?       → manage_visits / view_visits
#   - restricted_detail? → view_authorized_visits without full access (concierge)
#
# Scope rules (§5.3–5.5):
#   - tenant_admin / content_manager → all visits in the organization
#   - property_admin                 → all visits on assigned (managed) properties
#   - concierge                      → operational visits (authorized, checked_in,
#                                       recently checked_out) on assigned properties only
#   - resident/owner                 → visits linked to their active units only
#   - client without assignment      → no visits
#   - cross-organization             → always denied
#
class VisitPolicy < ApplicationPolicy
  # List: tenant_admin/property_admin (manage_visits), concierge (view_authorized_visits)
  def index?
    allowed?(:view_visits) || allowed?(:manage_visits) ||
      any_accessible_property?(:view_visits) || any_accessible_property?(:view_authorized_visits)
  end

  # Show: requires view_visits or view_authorized_visits scoped to the visit's property
  def show?
    return false unless same_organization?

    allowed?(:view_visits) || allowed?(:manage_visits) ||
      allowed?(:view_authorized_visits) || allowed?(:view_minimal_access_control_data) ||
      unit_context_visit_access?
  end

  # Contextual detail for owners/residents on their active units.
  def contextual_detail?
    return false unless same_organization?
    return false if full_detail? || restricted_detail?

    unit_context_visit_access?
  end

  # Full detail (administrative): exposes complete visit, person, actor, metadata
  # and functional history data. Drives the full vs. restricted serializer choice.
  # Tied to manage_visits (§5.7); concierge holds view_visits too but only ever
  # receives the restricted payload.
  def full_detail?
    return false unless same_organization?

    allowed?(:manage_visits)
  end

  # Restricted detail (concierge): only operational fields and minimal timeline.
  # Mutually exclusive with full_detail? so a single actor never gets both.
  def restricted_detail?
    return false unless same_organization?
    return false if full_detail?

    allowed?(:view_authorized_visits) || allowed?(:view_minimal_access_control_data)
  end

  # Create: residents and owners via create_visits, property_admin/tenant_admin via manage_visits
  def create?
    return false unless same_organization?

    allowed?(:create_visits) || allowed?(:manage_visits)
  end

  def new?
    create?
  end

  # Update: property_admin/tenant_admin
  def update?
    same_organization? && allowed?(:manage_visits)
  end

  def edit?
    update?
  end

  # Destroy: only org-wide managers
  def destroy?
    same_organization? && allowed?(:manage_visits)
  end

  # Authorize: resident or owner with authorize_visits, or administrators with manage_visits
  def authorize?
    return false unless same_organization?

    allowed?(:authorize_visits) || allowed?(:manage_visits)
  end

  # Check-in (register entry): concierge or property_admin on the visit's property
  def check_in?
    return false unless same_organization?

    allowed?(:register_visit_entry)
  end

  # Check-out (register exit): concierge or property_admin on the visit's property
  def check_out?
    return false unless same_organization?

    allowed?(:register_visit_exit)
  end

  # Cancel: administrators or unit authorizers while visit is still cancellable
  def cancel?
    return false unless same_organization?
    return false unless cancellable_visit?

    allowed?(:manage_visits) || allowed?(:authorize_visits)
  end

  # Resend notification: admin-only (operator-facing), and only when the
  # visit's notification_status is "failed" (see design.md Decision 7 —
  # resend is deliberately unavailable for "no_recipients"/"delivered").
  def resend_notification?
    return false unless same_organization?
    return false unless allowed?(:manage_visits)

    record.respond_to?(:notification_status) &&
      record.notification_status == Visit::NotificationStatuses::FAILED
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization

    def resolve
      return scope.none unless user.present?

      org = current_organization
      return scope.none unless org

      resolver = authorization_resolver
      return scope.none unless resolver

      # org-wide roles (tenant_admin, content_manager) see all visits in the organization
      return organization_scoped if resolver.allowed?(:view_visits) || resolver.allowed?(:manage_visits)

      profile = resolver.profile

      # Split property-scoped access by capability:
      #   - manage_visits        → property_admin, sees every status (managed)
      #   - view_authorized/visits without manage → concierge, operational only
      managed_property_ids = []
      operational_property_ids = []
      profile.property_capabilities.each do |property_id, caps|
        if caps.include?(Authorization::Capabilities::MANAGE_VISITS)
          managed_property_ids << property_id
        elsif caps.include?(Authorization::Capabilities::VIEW_AUTHORIZED_VISITS) ||
              caps.include?(Authorization::Capabilities::VIEW_VISITS)
          operational_property_ids << property_id
        end
      end

      # unit-scoped roles (owner/resident) see visits on their active units
      unit_ids = profile.unit_capabilities
                        .select do |_id, caps|
                          caps.include?(Authorization::Capabilities::CREATE_VISITS) ||
                            caps.include?(Authorization::Capabilities::AUTHORIZE_VISITS)
                        end
                        .keys

      base = organization_scoped
      clauses = []
      clauses << base.where(residential_property_id: managed_property_ids) if managed_property_ids.any?
      if operational_property_ids.any?
        clauses << base.where(residential_property_id: operational_property_ids).concierge_visible
      end
      clauses << base.where(unit_id: unit_ids) if unit_ids.any?

      return scope.none if clauses.empty?

      clauses.reduce { |relation, clause| relation.or(clause) }
    end
  end

  private

  def cancellable_visit?
    return false unless record.respond_to?(:status)

    record.status.in?([ VisitStatuses::PENDING, VisitStatuses::AUTHORIZED ])
  end

  def unit_context_visit_access?
    allowed?(:create_visits) || allowed?(:authorize_visits)
  end
end
