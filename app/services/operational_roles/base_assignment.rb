# frozen_string_literal: true

module OperationalRoles
  # Shared assignment logic for operational role services.
  #
  # == Input contract
  #   actor:                User — operator performing the action (for audit trail)
  #   person:               Person — target receiving the role
  #   organization:         Organization — current tenant
  #   residential_property: ResidentialProperty — scope; never global
  #
  # == Output contract
  #   { success: Boolean, assignment: StaffAssignment|nil, errors: Array<String> }
  #
  # Subclasses implement +target_staff_type+ and +requires_system_access?+.
  # +call+ is final; override hooks instead.
  class BaseAssignment
    def initialize(actor:, person:, organization:, residential_property:, starts_at: nil, ends_at: nil, status: nil)
      @actor = actor
      @person = person
      @organization = organization
      @residential_property = residential_property
      @starts_at = starts_at.presence || Date.current
      @ends_at = ends_at.presence
      @status = status.presence || StaffAssignment::STATUS_ACTIVE
    end

    def call
      errors = validate
      return failure(errors) if errors.any?

      assignment = ActsAsTenant.with_tenant(organization) do
        existing = StaffAssignment
          .where(
            organization_id: organization.id,
            person_id: person.id,
            residential_property_id: residential_property.id,
            staff_type: target_staff_type
          ).first

        if existing
          existing.update!(status: status, starts_at: starts_at, ends_at: ends_at)
          existing
        else
          StaffAssignment.create!(
            organization: organization,
            person: person,
            residential_property: residential_property,
            staff_type: target_staff_type,
            status: status,
            starts_at: starts_at,
            ends_at: ends_at
          )
        end
      end

      { success: true, assignment: assignment, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    attr_reader :actor, :person, :organization, :residential_property, :starts_at, :ends_at, :status

    # Override in subclass to return the persisted staff_type string.
    def target_staff_type
      raise NotImplementedError, "#{self.class} must implement #target_staff_type"
    end

    # Override to true in subclasses where system login is expected.
    def requires_system_access?
      false
    end

    def validate
      errors = []

      unless person.organization_id == organization.id
        errors << "Person does not belong to the given organization"
      end

      unless residential_property.organization_id == organization.id
        errors << "ResidentialProperty does not belong to the given organization"
      end

      if requires_system_access? && person.user_id.blank?
        errors << "Person must have a linked user account to be assigned this role"
      end

      errors
    end

    def failure(errors)
      { success: false, assignment: nil, errors: Array(errors) }
    end
  end
end
