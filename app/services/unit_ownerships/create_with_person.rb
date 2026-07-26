# frozen_string_literal: true

module UnitOwnerships
  class CreateWithPerson
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(unit:, ownership_params:, person_params:, actor:)
      @unit = unit
      @ownership_params = ownership_params.to_h.symbolize_keys
      @person_params = person_params.to_h.symbolize_keys
      @actor = actor
    end

    def call
      created_by = Mutation.actor_person(@actor, @unit.organization)

      Mutation.with_unit_lock(@unit) do
        person = resolve_person!
        ensure_membership!(person)

        ownership = UnitOwnership.new(
          Mutation.ownership_attributes(
            unit: @unit,
            person: person,
            ownership_params: @ownership_params,
            created_by_person: created_by
          )
        )
        ownership.save!
        ownership
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
