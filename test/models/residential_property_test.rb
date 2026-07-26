# frozen_string_literal: true

# == Schema Information
#
# Table name: residential_properties
#
#  id              :uuid             not null, primary key
#  address_line    :string
#  city            :string
#  code            :string
#  country         :string           default("Chile"), not null
#  deleted_at      :datetime
#  metadata        :jsonb            not null
#  name            :string           not null
#  normalized_name :string           not null
#  property_type   :string           not null
#  region          :string
#  status          :string           default("active"), not null
#  timezone        :string           default("America/Santiago"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_property_type_d2e2ee8ca6             (organization_id,property_type)
#  idx_residential_properties_organization_id_id               (organization_id,id) UNIQUE
#  idx_residential_properties_unique_code_per_org              (organization_id,code) UNIQUE WHERE ((code IS NOT NULL) AND (deleted_at IS NULL))
#  idx_residential_properties_unique_normalized_name_per_org   (organization_id,normalized_name) UNIQUE WHERE (deleted_at IS NULL)
#  index_residential_properties_on_deleted_at                  (deleted_at)
#  index_residential_properties_on_metadata                    (metadata) USING gin
#  index_residential_properties_on_organization_id             (organization_id)
#  index_residential_properties_on_organization_id_and_status  (organization_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
require "test_helper"

# Model-level contract for ResidentialProperty (improve-property-foundation §7):
# presence, name normalization, tenant-scoped case-insensitive name uniqueness,
# status inclusion, defaults, and the concurrent-uniqueness backstop.
class ResidentialPropertyTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  def build_property(**attrs)
    ResidentialProperty.new({
      name: "Model Property",
      property_type: PropertyTypes::BUILDING
    }.merge(attrs))
  end

  # 7.1 -----------------------------------------------------------------------
  test "7.1 valid property is valid and persists" do
    property = build_property(name: "Valid Foundation Property")
    assert property.valid?, property.errors.full_messages.to_sentence
    assert property.save
    assert_equal @organization.id, property.organization_id
  end

  # 7.2 -----------------------------------------------------------------------
  test "7.2 property without organization is rejected" do
    # Validate inside without_tenant so acts_as_tenant does not backfill the tenant.
    ActsAsTenant.without_tenant do
      property = build_property
      refute property.valid?
      assert property.errors.key?(:organization)
    end
  end

  # 7.3 -----------------------------------------------------------------------
  test "7.3 blank name is rejected" do
    property = build_property(name: "   ")
    refute property.valid?
    assert property.errors.key?(:name)
  end

  # 7.4 -----------------------------------------------------------------------
  test "7.4 duplicate normalized name in same organization is rejected" do
    create_property(@organization, "Parque Central")

    duplicate = build_property(name: "  parque   central ")
    refute duplicate.valid?
    assert_includes duplicate.errors[:name],
                    I18n.t("activerecord.errors.models.residential_property.attributes.name.taken")
  end

  # 7.5 -----------------------------------------------------------------------
  test "7.5 same normalized name is allowed in a different organization" do
    create_property(@organization, "Parque Central")

    # Build, validate and persist within the other tenant so acts_as_tenant keeps
    # the foreign organization instead of backfilling the current one.
    other = ActsAsTenant.with_tenant(@other_organization) do
      property = ResidentialProperty.new(
        organization: @other_organization,
        name: "Parque Central",
        property_type: PropertyTypes::BUILDING
      )
      assert property.valid?, property.errors.full_messages.to_sentence
      property.save!
      property
    end

    assert other.persisted?
  end

  # 7.6 -----------------------------------------------------------------------
  test "7.6 accepts every canonical status value" do
    PropertyStatuses::ALL.each do |status|
      property = build_property(name: "Status #{status}", status: status)
      assert property.valid?, "expected status #{status} to be valid"
    end
  end

  test "7.6 rejects a status outside the catalog" do
    property = build_property(status: "bogus")
    refute property.valid?
    assert property.errors.key?(:status)
  end

  # 7.7 -----------------------------------------------------------------------
  test "7.7 new record carries lifecycle and location defaults" do
    property = ResidentialProperty.new
    assert_equal PropertyStatuses::ACTIVE, property.status
    assert_equal "Chile", property.country
    assert_equal "America/Santiago", property.timezone
  end

  test "7.7 name is trimmed and whitespace-collapsed before validation" do
    property = build_property(name: "  Torre   Norte  ")
    property.validate
    assert_equal "Torre Norte", property.name
    assert_equal "torre norte", property.normalized_name
  end

  test "7.7 code stays optional but unique per organization when present" do
    create_property(@organization, "Code Holder").update!(code: "CODE-1")

    duplicate = build_property(name: "Other Property", code: "CODE-1")
    refute duplicate.valid?
    assert duplicate.errors.key?(:code)

    blank_code = build_property(name: "Yet Another Property", code: nil)
    assert blank_code.valid?, blank_code.errors.full_messages.to_sentence
  end

  # 7.18 ----------------------------------------------------------------------
  test "7.18 database unique index guards a concurrent duplicate name" do
    create_property(@organization, "Concurrent Name")

    racing = build_property(name: "Concurrent Name")
    # Bypass model validations to emulate a second request that committed between
    # this record's validation and INSERT; set the normalized column explicitly
    # since the normalizing callback is skipped with validate: false.
    racing.normalized_name = "concurrent name"
    assert_raises(ActiveRecord::RecordNotUnique) do
      racing.save(validate: false)
    end
  end

  test "7.18 register_uniqueness_conflict maps the index to a field error" do
    property = build_property
    exception = ActiveRecord::RecordNotUnique.new(
      "PG::UniqueViolation idx_residential_properties_unique_normalized_name_per_org"
    )

    property.register_uniqueness_conflict(exception)
    assert property.errors.key?(:name)
  end
end
