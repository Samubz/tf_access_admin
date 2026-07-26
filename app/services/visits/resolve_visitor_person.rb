# frozen_string_literal: true

module Visits
  class ResolveVisitorPerson
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, person_id: nil, person_params: nil)
      @organization = organization
      @person_id = person_id
      @person_params = person_params.to_h.symbolize_keys if person_params.present?
    end

    def call
      return @organization.people.find(@person_id) if @person_id.present?

      raise ArgumentError, "visitor person is required" if @person_params.blank?

      resolve_from_params!
    end

    private

    def resolve_from_params!
      existing = People::FindExisting.call(
        organization: @organization,
        document_number: @person_params[:document_number],
        email: normalized_email
      )
      return existing if existing

      person = build_person
      ActiveRecord::Base.transaction do
        person.save!
        ensure_membership!(person)
      end
      person
    end

    def build_person
      first_name = @person_params[:first_name].to_s.strip.presence
      last_name = @person_params[:last_name].to_s.strip.presence
      display_name = @person_params[:display_name].to_s.strip.presence
      display_name ||= [ first_name, last_name ].compact.join(" ").strip.presence

      person = Person.new(
        organization: @organization,
        first_name: first_name,
        last_name: last_name,
        display_name: display_name,
        person_type: @person_params[:person_type].presence || PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.document_number = @person_params[:document_number]
      person.contact_email = normalized_email
      person.contact_phone = @person_params[:phone].to_s.strip.presence
      person
    end

    def ensure_membership!(person)
      membership = person.organization_membership
      return membership if membership.present?

      membership = OrganizationMembership.create!(organization: @organization, person: person)
      membership.accept! if membership.may_accept?
      membership
    end

    def normalized_email
      (@person_params[:contact_email] || @person_params[:email]).to_s.downcase.strip.presence
    end
  end
end
