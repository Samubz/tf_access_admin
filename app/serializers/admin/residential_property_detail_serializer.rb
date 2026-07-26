# frozen_string_literal: true

# Read-only props for the property detail page (add-property-detail-view).
# Reuses the wizard's persisted preview/confirmation data contract so
# structure/unit counts never drift between the wizard and the detail page.
class Admin::ResidentialPropertyDetailSerializer
  def initialize(property:, current_user:)
    @property = property
    @current_user = current_user
  end

  def as_json
    {
      property: property_json,
      organization: organization_json,
      preview: preview_json,
      permissions: permissions_json,
      next_actions: next_actions_json
    }
  end

  private

  def property_json
    Admin::ResidentialPropertySerializer.new(@property, current_user: @current_user).as_json
  end

  def organization_json
    { id: @property.organization.id, name: @property.organization.name }
  end

  def preview_json
    Properties::Setup::BuildPreview.call(property: @property, actor: @current_user)
  end

  def permissions_json
    policy = ResidentialPropertyPolicy.new(@current_user, @property)
    unit_policy = UnitPolicy.new(@current_user, Unit)

    {
      edit: policy.update? && PropertyStatuses::DETAIL_EDITABLE.include?(@property.status),
      manage_units: unit_policy.property_allowed?(:manage_units, property: @property)
    }
  end

  def next_actions_json
    Properties::Setup::NextActions.call(property: @property, actor: @current_user)
  end
end
