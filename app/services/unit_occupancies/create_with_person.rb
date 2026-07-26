# frozen_string_literal: true

module UnitOccupancies
  class CreateWithPerson
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(unit:, occupancy_params:, person_params:, actor:)
      @unit = unit
      @occupancy_params = occupancy_params.to_h.symbolize_keys
      @person_params = person_params.to_h.symbolize_keys
      @actor = actor
    end

    def call
      Mutation.with_unit_lock(@unit) do
        ActiveRecord::Base.transaction do
          person = resolve_person!
          ensure_membership!(person)

          occupancy = UnitOccupancy.new(
            Mutation.occupancy_attributes(
              unit: @unit,
              person: person,
              occupancy_params: @occupancy_params
            )
          )
          occupancy.save!
          occupancy
        end
      end
    end

    private

    def resolve_person!
      existing = People::FindExisting.call(
        organization: @unit.organization,
        document_number: @person_params[:document_number],
        email: normalized_email
      )
      return existing if existing

      person = build_person
      person.save!
      person
    end

    def build_person
      first_name = @person_params[:first_name].to_s.strip.presence
      last_name = @person_params[:last_name].to_s.strip.presence

      person = Person.new(
        organization: @unit.organization,
        first_name: first_name,
        last_name: last_name,
        display_name: @person_params[:display_name],
        person_type: @person_params[:person_type].presence || PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.document_number = @person_params[:document_number]
      person.contact_email = normalized_email
      person
    end

    def ensure_membership!(person)
      membership = person.organization_membership
      return membership if membership.present?

      membership = OrganizationMembership.create!(organization: person.organization, person: person)
      membership.accept! if membership.may_accept?
      membership
    end

    def normalized_email
      (@person_params[:contact_email] || @person_params[:email]).to_s.downcase.strip.presence
    end
  end
end
