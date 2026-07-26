# frozen_string_literal: true

module People
  # Creates a new +Person+ identity within an organization. Pure creation: it
  # does not resolve duplicates (callers resolve via +ResolveIdentityMatch+
  # first), does not create an account, and does not create unit relationships.
  class Create
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, first_name: nil, last_name: nil, display_name: nil,
                   email: nil, phone: nil, document_number: nil, birthdate: nil,
                   person_type: PersonTypes::NATURAL)
      @organization = organization
      @first_name = first_name
      @last_name = last_name
      @display_name = display_name
      @email = email
      @phone = phone
      @document_number = document_number
      @birthdate = birthdate
      @person_type = person_type
    end

    def call
      person = Person.new(
        organization: @organization,
        first_name: @first_name,
        last_name: @last_name,
        display_name: @display_name,
        person_type: @person_type,
        status: PersonStatuses::ACTIVE,
        birthdate: @birthdate
      )
      person.document_number = @document_number if @document_number.present?
      person.contact_email = @email if @email.present?
      person.contact_phone = @phone if @phone.present?
      person.save!
      person
    end
  end
end
