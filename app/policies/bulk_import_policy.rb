# frozen_string_literal: true

class BulkImportPolicy < ApplicationPolicy
  def create?
    allowed?(:manage_properties) || any_accessible_property?(:manage_units)
  end

  # Used by Admin::People::BulkImportsController#create, which is
  # organization-scoped (not tied to a residential property/section), unlike
  # the units bulk import (add-bulk-user-import).
  def create_people_import?
    allowed?(:manage_people)
  end

  def update?
    bulk_import_allowed?
  end

  def validate?
    update?
  end

  def rows?
    update?
  end

  def confirm?
    update?
  end

  def status?
    update?
  end

  def report?
    update?
  end

  def trigger_invitations?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization

    def resolve
      return scope.none unless user.present?

      org = current_organization
      return scope.none unless org

      base = organization_scoped
      resolver = authorization_resolver
      return scope.none unless resolver

      return base if resolver.allowed?(:manage_properties)

      people_scope = resolver.allowed?(:manage_people) ? base.where(import_type: BulkImport::IMPORT_TYPES[:users]) : base.none

      property_ids = accessible_property_ids
      return people_scope if property_ids.empty?

      base.where(residential_property_id: property_ids).or(people_scope)
    end
  end

  private

  def bulk_import_allowed?
    return false unless same_organization?
    return allowed?(:manage_people) if people_import?

    if record.residential_property_id.blank?
      return allowed?(:manage_properties)
    end

    property = record.residential_property
    return false unless property

    property_accessible?(property) && allowed?(:manage_units)
  end

  def people_import?
    record.import_type == BulkImport::IMPORT_TYPES[:users]
  end
end
