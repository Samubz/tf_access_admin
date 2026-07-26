# frozen_string_literal: true

class ApplicationPolicy
  include ResidentialPropertyContext

  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "User must be logged in" unless user

    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def resolver
    @resolver ||= build_resolver
  end

  def allowed?(capability)
    resolver&.allowed?(capability) || false
  end

  def property_accessible?(property)
    resolver&.property_accessible?(property) || false
  end

  def any_accessible_property?(capability)
    return allowed?(capability) if resolver&.profile&.organization_wide?

    resolver.accessible_property_ids.any? do |property_id|
      property_allowed?(capability, property_id: property_id)
    end
  end

  def property_allowed?(capability, property: nil, property_id: nil)
    target_property = property || ResidentialProperty.find_by(
      id: property_id,
      organization_id: current_organization&.id
    )
    return false unless target_property

    scoped = scoped_resolver(property: target_property)
    scoped&.allowed?(capability) || false
  end

  def viewing_own_person?
    return false unless record.is_a?(Person)

    user.person_for(current_organization)&.id == record.id
  end

  def admin?
    user.present? && (user.super_admin? || user.tenant_admin?(ActsAsTenant.current_tenant))
  end

  def super_admin?
    user.present? && user.super_admin?
  end

  def same_organization?
    return false unless user.present?

    org = current_organization
    return false unless org&.id
    return true if user.super_admin?
    return false unless member_of_current_organization?

    if record.is_a?(User)
      same_user_organization_membership?(org)
    elsif record.is_a?(Organization)
      record.id == org.id
    elsif index_record?
      true
    elsif record.respond_to?(:organization_id)
      record.organization_id == org.id
    else
      false
    end
  end

  def same_user?
    return false unless user.present?
    return false unless record.respond_to?(:id)
    return false unless user.respond_to?(:id)

    record.id == user.id
  end

  class Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, "User must be logged in" unless user

      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  def build_resolver
    org = current_organization
    return nil if org.blank?

    context = resolver_context

    if resolver_via_current?(org)
      Current.authorization_resolver(**context)
    else
      Authorization::Resolver.new(
        user: user,
        organization: org,
        **context
      )
    end
  end

  def resolver_via_current?(org)
    Current.user == user && Current.organization == org
  end

  def resolver_context
    if index_record?
      { property: nil, unit: nil, record: nil }
    else
      {
        property: record_residential_property,
        unit: record_unit,
        record: record
      }
    end
  end

  def current_organization
    Current.organization || ActsAsTenant.current_tenant
  end

  def member_of_current_organization?
    org = current_organization
    return false unless org

    user.member_of_tenant?(org)
  end

  def same_user_organization_membership?(org)
    user.people.exists?(organization_id: org.id) &&
      record.people.exists?(organization_id: org.id)
  end

  def index_record?
    record.is_a?(Class) || record.nil?
  end

  def scoped_resolver(property: nil, unit: nil, record: nil)
    base = resolver
    return nil unless base

    Authorization::Resolver.new(
      user: user,
      organization: current_organization,
      property: property,
      unit: unit,
      record: record,
      profile: base.profile
    )
  end
end
