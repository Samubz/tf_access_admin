# frozen_string_literal: true

# Administrative serializer for ResidentialProperty (improve-property-foundation §5.7).
# Exposes backend-computed permissions/actions so the UI can gate edit, lifecycle
# transitions and archive without inferring rules from status alone.
class Admin::ResidentialPropertySerializer < ActiveModel::Serializer
  attributes :id, :name, :code, :property_type, :address_line, :city, :region, :country,
             :timezone, :status, :metadata, :organization_id, :created_at, :updated_at,
             :permissions, :actions

  def permissions
    @permissions ||= begin
      policy = build_policy
      archived = object.status == PropertyStatuses::ARCHIVED

      {
        update: policy.update? && !archived,
        activate: policy.update? && object.status == PropertyStatuses::INACTIVE,
        deactivate: policy.update? && object.status == PropertyStatuses::ACTIVE,
        archive: policy.archive? && !archived
      }
    end
  end

  def actions
    permissions.filter_map { |action, allowed| action.to_s if allowed }
  end

  private

  def build_policy
    @instance_options[:policy] || ResidentialPropertyPolicy.new(current_user, object)
  end

  def current_user
    @instance_options[:current_user] || scope
  end
end
