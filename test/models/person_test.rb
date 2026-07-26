# frozen_string_literal: true

# == Schema Information
#
# Table name: people
#
#  id                         :uuid             not null, primary key
#  birthdate                  :date
#  deleted_at                 :datetime
#  display_name               :string           not null
#  document_number_ciphertext :text
#  document_number_digest     :string
#  document_type              :string
#  email_ciphertext           :text
#  first_name                 :string
#  last_name                  :string
#  metadata                   :jsonb            not null
#  person_type                :string           default("natural"), not null
#  phone_ciphertext           :text
#  status                     :string           default("active"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  organization_id            :uuid             not null
#  user_id                    :uuid
#
# Indexes
#
#  idx_people_unique_document_per_org_when_present   (organization_id,document_type,document_number_digest) UNIQUE WHERE ((document_number_digest IS NOT NULL) AND (deleted_at IS NULL))
#  idx_people_unique_user_per_org_when_present       (organization_id,user_id) UNIQUE WHERE ((user_id IS NOT NULL) AND (deleted_at IS NULL))
#  index_people_on_deleted_at                        (deleted_at)
#  index_people_on_metadata                          (metadata) USING gin
#  index_people_on_organization_id                   (organization_id)
#  index_people_on_organization_id_and_display_name  (organization_id,display_name)
#  index_people_on_organization_id_and_status        (organization_id,status)
#  index_people_on_organization_id_and_user_id       (organization_id,user_id)
#  index_people_on_user_id                           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class PersonTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "has many unit occupancies" do
    person = create_person!(display_name: "Occupancy Association")
    unit = create_unit!(identifier: "PERSON-OCC-1")
    occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: unit,
      person: person,
      occupancy_type: OccupancyTypes::TENANT,
      status: OccupancyStatuses::ACTIVE,
      starts_at: Time.current
    )

    assert_includes person.unit_occupancies.reload, occupancy
  end

  test "has many visitor profiles" do
    person = create_person!(display_name: "Visitor Association")
    profile = VisitorProfile.create!(
      organization: @organization,
      person: person,
      status: "active"
    )

    assert_includes person.visitor_profiles.reload, profile
  end

  test "rejects duplicate document within same organization" do
    create_person!(display_name: "Original Document", document_number: "11.111.111-1")

    duplicate = Person.new(
      organization: @organization,
      display_name: "Duplicate Document",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    duplicate.document_number = "11111111-1"

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:document_number], "admin.people.validations.document_taken"
  end

  test "rejects duplicate email within same organization via metadata" do
    original = Person.new(
      organization: @organization,
      display_name: "Original Email",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    original.contact_email = "duplicate@example.test"
    original.save!

    duplicate = Person.new(
      organization: @organization,
      display_name: "Duplicate Email",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    duplicate.contact_email = "duplicate@example.test"

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:contact_email], "admin.people.validations.email_taken"
  end

  test "rejects duplicate email when another person is linked to user with same email" do
    user = ActsAsTenant.without_tenant do
      User.create!(
        email: "linked-duplicate@example.test",
        password: "Password1@",
        password_confirmation: "Password1@",
        name: "Linked Duplicate",
        dni: SecureRandom.hex(4),
        language: Languages::ES,
        confirmed_at: Time.current
      )
    end
    Person.create!(
      organization: @organization,
      user: user,
      display_name: "Linked Duplicate",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )

    duplicate = Person.new(
      organization: @organization,
      display_name: "Metadata Duplicate",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    duplicate.contact_email = "linked-duplicate@example.test"

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:contact_email], "admin.people.validations.email_taken"
  end

  test "allows same document in different organizations" do
    ActsAsTenant.with_tenant(@other_organization) do
      create_person!(
        organization: @other_organization,
        display_name: "Other Org Document",
        document_number: "22.222.222-2"
      )
    end

    person = Person.new(
      organization: @organization,
      display_name: "Same Document Other Org",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    person.document_number = "22222222-2"

    assert person.valid?, person.errors.full_messages.to_sentence
  end

  test "allows same email in different organizations" do
    ActsAsTenant.with_tenant(@other_organization) do
      other = Person.new(
        organization: @other_organization,
        display_name: "Other Org Email",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      other.contact_email = "cross-org@example.test"
      other.save!
    end

    person = Person.new(
      organization: @organization,
      display_name: "Same Email Other Org",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    person.contact_email = "cross-org@example.test"

    assert person.valid?, person.errors.full_messages.to_sentence
  end

  test "allows updating person without changing document or email" do
    person = create_person!(
      display_name: "Updatable Person",
      document_number: "33.333.333-3"
    )
    person.contact_email = "updatable@example.test"
    person.save!

    person.display_name = "Updated Name"

    assert person.valid?, person.errors.full_messages.to_sentence
    assert person.save
  end

  private

  def create_person!(display_name:, document_number: nil, organization: @organization)
    person = Person.new(
      organization: organization,
      display_name: display_name,
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    person.document_number = document_number if document_number.present?
    person.save!
    person
  end

  def create_unit!(identifier:)
    property = ResidentialProperty.create!(
      organization: @organization,
      name: "Person Test Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    Unit.create!(
      organization: @organization,
      residential_property: property,
      identifier: identifier,
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
  end
end
