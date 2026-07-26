# frozen_string_literal: true

module OperationalPolicyTestHelper
  def create_property(organization, name)
    ResidentialProperty.create!(
      organization: organization,
      name: name,
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  def create_unit(property, identifier)
    Unit.create!(
      organization: property.organization,
      residential_property: property,
      identifier: identifier,
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
  end

  def soft_delete_unit(unit)
    unit.authorize_soft_delete!
    unit.destroy
  end

  def create_staff_user(organization:, email:, staff_type:, property:, role: AvailableRoles::CLIENT)
    user = create_user_for_organization(
      organization: organization,
      email: email,
      role: role
    )

    StaffAssignment.create!(
      organization: organization,
      person: user.person_for(organization),
      residential_property: property,
      staff_type: staff_type,
      status: "active",
      starts_at: Date.current
    )

    user
  end

  def create_owner_user(organization:, email:, unit:)
    user = create_user_for_organization(
      organization: organization,
      email: email,
      role: AvailableRoles::CLIENT
    )
    person = user.person_for(organization)

    UnitOwnership.create!(
      organization: organization,
      person: person,
      unit: unit,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    user
  end

  def create_resident_user(organization:, email:, unit:)
    user = create_user_for_organization(
      organization: organization,
      email: email,
      role: AvailableRoles::CLIENT
    )
    person = user.person_for(organization)

    UnitOccupancy.create!(
      organization: organization,
      person: person,
      unit: unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.zone.now,
      status: OccupancyStatuses::ACTIVE
    )

    user
  end
end
