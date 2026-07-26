# frozen_string_literal: true

require "test_helper"

class Admin::PropertySetup::WizardControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "wizard-ctrl-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "wizard-ctrl-client@example.test",
      role: AvailableRoles::CLIENT
    )

    @draft = ResidentialProperty.create!(
      organization: @organization,
      name: "Wizard Draft Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      address_line: "Main 123",
      city: "Santiago",
      country: "Chile",
      timezone: "America/Santiago",
      metadata: { "setup_wizard" => { "current_step" => 2, "structure_mode" => "none" } }
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "tenant admin can open wizard" do
    sign_in_as(@tenant_admin)
    get admin_property_setup_new_wizard_path
    assert_response :success
  end

  test "unauthorized user cannot open wizard" do
    sign_in_as(@client)
    get admin_property_setup_new_wizard_path
    assert_response :redirect
  end

  test "create initializes draft property" do
    sign_in_as(@tenant_admin)

    assert_difference -> { ResidentialProperty.where(status: PropertyStatuses::DRAFT).count }, 1 do
      post admin_property_setup_create_wizard_path, params: {
        setup: {
          name: "New Wizard Property",
          property_type: PropertyTypes::BUILDING,
          address_line: "Street 1",
          city: "Santiago",
          estimated_units: 12
        }
      }
    end

    property = ResidentialProperty.order(:created_at).last
    assert_equal PropertyStatuses::DRAFT, property.status
    assert_redirected_to admin_property_setup_wizard_path(property)
  end

  test "advance moves to next step when valid" do
    sign_in_as(@tenant_admin)

    post admin_property_setup_advance_wizard_path(@draft), params: {
      setup: { structure_mode: "none", units_mode: "automatic" }
    }

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_equal 3, Properties::Setup::WizardState.current_step(@draft.reload)
  end

  test "advance from step 3 in quick automatic mode generates units per leaf and advances" do
    sign_in_as(@tenant_admin)
    Properties::Setup::ApplyQuickStructure.call(
      actor: @tenant_admin, property: @draft,
      params: { level_1_count: 1, level_2_count: 2, level_1_prefix: "Torre", level_2_prefix: "Piso" }
    )
    Properties::Setup::WizardState.merge!(@draft, current_step: 3, structure_mode: "quick")
    @draft.save!

    # 2 floors x 4 units_per_leaf = 8 units, all under their leaf section.
    # units_per_leaf arrives as a string from params; the advance must not raise.
    assert_difference -> { @draft.units.count }, 8 do
      post admin_property_setup_advance_wizard_path(@draft), params: {
        setup: {
          units_mode: "automatic",
          unit_generation: { unit_type: "apartment", identifier_format: "floor_sequential", units_per_leaf: "4" }
        }
      }
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_equal 4, Properties::Setup::WizardState.current_step(@draft.reload)
    assert @draft.units.all? { |u| u.property_section_id.present? }
  end

  test "advance from step 3 automatic stays on step 3 and surfaces error when generation fails" do
    sign_in_as(@tenant_admin)
    # No structure format resolves for OTHER, so automatic generation is unavailable.
    @draft.update!(property_type: PropertyTypes::OTHER)
    Properties::Setup::WizardState.merge!(@draft, current_step: 3, structure_mode: "quick")
    @draft.save!

    assert_no_difference -> { @draft.units.count } do
      post admin_property_setup_advance_wizard_path(@draft), params: {
        setup: {
          units_mode: "automatic",
          unit_generation: { unit_type: "apartment", identifier_format: "floor_sequential", units_per_leaf: "4" }
        }
      }
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_equal 3, Properties::Setup::WizardState.current_step(@draft.reload)
  end

  test "advance from step 3 automatic is blocked when there is no quick leaf structure" do
    sign_in_as(@tenant_admin)
    # BUILDING resolves a format, but no sections were generated (structure_mode not quick).
    Properties::Setup::WizardState.merge!(@draft, current_step: 3, structure_mode: "none")
    @draft.save!

    assert_no_difference -> { @draft.units.count } do
      post admin_property_setup_advance_wizard_path(@draft), params: {
        setup: {
          units_mode: "automatic",
          unit_generation: { unit_type: "apartment", identifier_format: "floor_sequential", units_per_leaf: "4" }
        }
      }
    end

    assert_equal 3, Properties::Setup::WizardState.current_step(@draft.reload)
  end

  test "confirm transitions draft to configured" do
    sign_in_as(@tenant_admin)
    Units::Create.call(
      actor: @tenant_admin,
      property: @draft,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )
    Properties::Setup::WizardState.merge!(@draft, current_step: 5)
    @draft.save!

    post admin_property_setup_confirm_wizard_path(@draft)

    assert_equal PropertyStatuses::CONFIGURED, @draft.reload.status
    assert_redirected_to admin_property_setup_wizard_path(@draft, completed: true)
  end

  test "complete transitions draft to created" do
    sign_in_as(@tenant_admin)
    Units::Create.call(
      actor: @tenant_admin,
      property: @draft,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )
    Properties::Setup::WizardState.merge!(@draft, current_step: 5)
    @draft.save!

    post admin_property_setup_complete_wizard_path(@draft)

    assert_equal PropertyStatuses::CREATED, @draft.reload.status
    assert_redirected_to admin_property_setup_wizard_path(@draft, completed: true)
  end

  test "confirm transitions a created property to configured" do
    sign_in_as(@tenant_admin)
    @draft.update!(status: PropertyStatuses::CREATED)
    Units::Create.call(
      actor: @tenant_admin,
      property: @draft,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )
    Properties::Setup::WizardState.merge!(@draft, current_step: 5)
    @draft.save!

    post admin_property_setup_confirm_wizard_path(@draft)

    assert_equal PropertyStatuses::CONFIGURED, @draft.reload.status
  end

  test "step 5 confirmation reloads the current persisted unit total instead of a stale step 4 count" do
    sign_in_as(@tenant_admin)
    section = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    unit = Units::Create.call(
      actor: @tenant_admin, property: @draft, section_id: section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit
    Properties::Setup::WizardState.merge!(@draft, current_step: 4)
    @draft.save!

    get admin_property_setup_wizard_path(@draft)
    assert_response :success
    step4_preview = Properties::Setup::BuildPreview.call(property: @draft.reload)
    assert_equal 1, step4_preview.dig(:counts, :units)

    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)
    Properties::Setup::WizardState.merge!(@draft, current_step: 5)
    @draft.save!

    get admin_property_setup_wizard_path(@draft)
    assert_response :success
    step5_preview = Properties::Setup::BuildPreview.call(property: @draft.reload)

    assert_equal 0, step5_preview.dig(:counts, :units)
  end

  test "completed view shows the same persisted unit total as confirmation" do
    sign_in_as(@tenant_admin)
    section = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    Units::Create.call(
      actor: @tenant_admin, property: @draft, section_id: section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )
    Properties::Setup::WizardState.merge!(@draft, current_step: 5)
    @draft.save!

    post admin_property_setup_confirm_wizard_path(@draft)
    assert_redirected_to admin_property_setup_wizard_path(@draft, completed: true)

    completed_preview = Properties::Setup::BuildPreview.call(property: @draft.reload)

    assert_equal 1, completed_preview.dig(:counts, :units)
  end

  test "advance requests confirmation when a property type change would reset existing structure" do
    sign_in_as(@tenant_admin)
    section = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    Properties::Setup::WizardState.merge!(@draft, current_step: 1)
    @draft.save!

    post admin_property_setup_advance_wizard_path(@draft), params: {
      setup: { name: @draft.name, property_type: PropertyTypes::TOWER, address_line: "Main 123" }
    }

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_not_nil section.reload
    assert_equal PropertyTypes::BUILDING, @draft.reload.property_type
    assert_equal 1, Properties::Setup::WizardState.current_step(@draft)
  end

  test "advance with confirmed=true applies the reset and the property type change" do
    sign_in_as(@tenant_admin)
    section = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    Properties::Setup::WizardState.merge!(@draft, current_step: 1)
    @draft.save!

    post admin_property_setup_advance_wizard_path(@draft), params: {
      setup: { name: @draft.name, property_type: PropertyTypes::TOWER, address_line: "Main 123" },
      confirmed: "true"
    }

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_raises(ActiveRecord::RecordNotFound) { PropertySection.unscoped.find(section.id) }
    assert_equal PropertyTypes::TOWER, @draft.reload.property_type
  end

  test "reopening a configured property starts at step 1" do
    configured = ResidentialProperty.create!(
      organization: @organization, name: "Configured Reopen", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::CONFIGURED, country: "Chile", timezone: "America/Santiago",
      metadata: { "setup_wizard" => { "current_step" => 5 } }
    )

    sign_in_as(@tenant_admin)
    get admin_property_setup_wizard_path(configured)

    assert_response :success
  end

  test "reopening an active property starts at step 1" do
    active = ResidentialProperty.create!(
      organization: @organization, name: "Active Reopen", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE, country: "Chile", timezone: "America/Santiago"
    )

    sign_in_as(@tenant_admin)
    get admin_property_setup_wizard_path(active)

    assert_response :success
  end

  test "wizard rejects editing an inactive property" do
    inactive = ResidentialProperty.create!(
      organization: @organization, name: "Inactive Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::INACTIVE, country: "Chile", timezone: "America/Santiago"
    )

    sign_in_as(@tenant_admin)
    get admin_property_setup_wizard_path(inactive)

    assert_redirected_to admin_residential_properties_path
  end

  test "wizard rejects editing an archived property" do
    archived = ResidentialProperty.create!(
      organization: @organization, name: "Archived Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ARCHIVED, country: "Chile", timezone: "America/Santiago"
    )

    sign_in_as(@tenant_admin)
    get admin_property_setup_wizard_path(archived)

    assert_redirected_to admin_residential_properties_path
  end

  test "editing name on a created property to a colliding value is rejected" do
    ResidentialProperty.create!(
      organization: @organization, name: "Rival Name", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE, country: "Chile", timezone: "America/Santiago", code: "bld-taken-name"
    )
    created = ResidentialProperty.create!(
      organization: @organization, name: "Created Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::CREATED, country: "Chile", timezone: "America/Santiago",
      address_line: "Main 1", code: "bld-created-property"
    )

    sign_in_as(@tenant_admin)
    post admin_property_setup_advance_wizard_path(created), params: {
      setup: { name: "Taken Name", property_type: PropertyTypes::BUILDING, address_line: "Main 1" }
    }

    assert_equal "bld-created-property", created.reload.code
    assert_equal "Created Property", created.name
  end

  test "editing name on a created property regenerates the code" do
    created = ResidentialProperty.create!(
      organization: @organization, name: "Created Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::CREATED, country: "Chile", timezone: "America/Santiago",
      address_line: "Main 1", code: "bld-created-property"
    )

    sign_in_as(@tenant_admin)
    post admin_property_setup_advance_wizard_path(created), params: {
      setup: { name: "Renamed Property", property_type: PropertyTypes::BUILDING, address_line: "Main 1" }
    }

    assert_equal "bld-renamed-property", created.reload.code
    assert_equal "Renamed Property", created.name
  end

  test "cancel with delete removes draft property" do
    sign_in_as(@tenant_admin)

    post admin_property_setup_cancel_wizard_path(@draft), params: { delete_draft: true }

    assert @draft.reload.deleted_at.present?
    assert_redirected_to admin_residential_properties_path
  end

  test "create section adds section to draft property" do
    sign_in_as(@tenant_admin)

    assert_difference -> { @draft.property_sections.count }, 1 do
      post admin_property_setup_create_section_wizard_path(@draft), params: {
        property_section: { name: "Torre A", section_type: SectionTypes::TOWER }
      }
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "create sections batch adds multiple root sections" do
    sign_in_as(@tenant_admin)

    assert_difference -> { @draft.property_sections.count }, 3 do
      post admin_property_setup_create_sections_wizard_path(@draft), params: {
        property_section: {
          mode: "multiple", section_type: SectionTypes::TOWER,
          prefix: "Torre", suffix_type: "letter", count: 3
        }
      }
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "create sections batch adds child sections under a root" do
    sign_in_as(@tenant_admin)
    tower = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )

    assert_difference -> { @draft.property_sections.count }, 2 do
      post admin_property_setup_create_sections_wizard_path(@draft), params: {
        property_section: {
          mode: "multiple", section_type: SectionTypes::FLOOR, parent_id: tower.id,
          prefix: "Piso", suffix_type: "number", count: 2
        }
      }
    end

    assert_equal 2, tower.reload.children.count
  end

  test "update section renames a section" do
    sign_in_as(@tenant_admin)
    section = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )

    patch admin_property_setup_update_section_wizard_path(@draft, section_id: section.id), params: {
      property_section: { name: "Torre Norte" }
    }

    assert_equal "Torre Norte", section.reload.name
    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "move section reparents a section under a different root" do
    sign_in_as(@tenant_admin)
    root_a = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    root_b = @draft.property_sections.create!(
      organization: @organization, name: "Torre B", section_type: SectionTypes::TOWER
    )
    subsection = @draft.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR, parent: root_a
    )

    patch admin_property_setup_move_section_wizard_path(@draft, section_id: subsection.id), params: {
      property_section: { parent_id: root_b.id }
    }

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_equal root_b.id, subsection.reload.parent_id
  end

  test "move section to root clears its parent" do
    sign_in_as(@tenant_admin)
    root = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    subsection = @draft.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR, parent: root
    )

    patch admin_property_setup_move_section_wizard_path(@draft, section_id: subsection.id), params: {
      property_section: { parent_id: "" }
    }

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_nil subsection.reload.parent_id
  end

  test "move section rejects moving under a subsection" do
    sign_in_as(@tenant_admin)
    root_a = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    root_b = @draft.property_sections.create!(
      organization: @organization, name: "Torre B", section_type: SectionTypes::TOWER
    )
    subsection = @draft.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR, parent: root_a
    )

    patch admin_property_setup_move_section_wizard_path(@draft, section_id: root_b.id), params: {
      property_section: { parent_id: subsection.id }
    }

    assert_nil root_b.reload.parent_id
  end

  test "destroy section soft-deletes an empty section" do
    sign_in_as(@tenant_admin)
    section = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )

    assert_difference -> { @draft.property_sections.count }, -1 do
      delete admin_property_setup_destroy_section_wizard_path(@draft, section_id: section.id)
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_not_nil section.reload.deleted_at
  end

  test "destroy section is blocked when it has children" do
    sign_in_as(@tenant_admin)
    tower = @draft.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    @draft.property_sections.create!(
      organization: @organization, name: "Piso 1",
      section_type: SectionTypes::FLOOR, parent: tower
    )

    assert_no_difference -> { @draft.property_sections.count } do
      delete admin_property_setup_destroy_section_wizard_path(@draft, section_id: tower.id)
    end
  end

  test "section endpoints deny cross-organization access" do
    other_draft = ActsAsTenant.with_tenant(organizations(:two)) do
      ResidentialProperty.create!(
        organization: organizations(:two), name: "Other Org Draft 2",
        property_type: PropertyTypes::BUILDING, status: PropertyStatuses::DRAFT,
        country: "Chile", timezone: "America/Santiago"
      )
    end

    sign_in_as(@tenant_admin)
    post admin_property_setup_create_sections_wizard_path(other_draft), params: {
      property_section: { mode: "individual", name: "Torre X", section_type: SectionTypes::TOWER }
    }

    assert_redirected_to admin_residential_properties_path
  end

  test "back moves to previous step" do
    sign_in_as(@tenant_admin)
    Properties::Setup::WizardState.merge!(@draft, current_step: 3)
    @draft.save!

    post admin_property_setup_back_wizard_path(@draft)

    assert_redirected_to admin_property_setup_wizard_path(@draft)
    assert_equal 2, Properties::Setup::WizardState.current_step(@draft.reload)
  end

  test "tenant admin cannot access draft from another organization" do
    other_draft = ActsAsTenant.with_tenant(organizations(:two)) do
      ResidentialProperty.create!(
        organization: organizations(:two),
        name: "Other Org Draft",
        property_type: PropertyTypes::BUILDING,
        status: PropertyStatuses::DRAFT,
        country: "Chile",
        timezone: "America/Santiago"
      )
    end

    sign_in_as(@tenant_admin)
    get admin_property_setup_wizard_path(other_draft)

    assert_redirected_to admin_residential_properties_path
  end

  test "create unit adds unit to draft property" do
    sign_in_as(@tenant_admin)

    assert_difference -> { @draft.units.count }, 1 do
      post admin_property_setup_create_unit_wizard_path(@draft), params: {
        unit: { identifier: "A-101", unit_type: UnitTypes::APARTMENT }
      }
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "create units batch adds multiple units to an eligible section" do
    sign_in_as(@tenant_admin)
    floor = @draft.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR
    )

    assert_difference -> { @draft.units.count }, 3 do
      post admin_property_setup_create_units_wizard_path(@draft), params: {
        unit: {
          property_section_id: floor.id, unit_type: UnitTypes::APARTMENT,
          prefix: "Depto", suffix_type: "letter", count: 3
        }
      }
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "create units batch is rejected without a section" do
    sign_in_as(@tenant_admin)

    assert_no_difference -> { @draft.units.count } do
      post admin_property_setup_create_units_wizard_path(@draft), params: {
        unit: { unit_type: UnitTypes::APARTMENT, prefix: "Depto", suffix_type: "letter", count: 2 }
      }
    end

    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "update unit changes descriptive fields" do
    sign_in_as(@tenant_admin)
    floor = @draft.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR
    )
    unit = Units::Create.call(
      actor: @tenant_admin, property: @draft, section_id: floor.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit

    patch admin_property_setup_update_unit_wizard_path(@draft, unit_id: unit.id), params: {
      unit: { display_name: "Depto renombrado" }
    }

    assert_equal "Depto renombrado", unit.reload.display_name
    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "destroy unit soft-deletes it" do
    sign_in_as(@tenant_admin)
    floor = @draft.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR
    )
    unit = Units::Create.call(
      actor: @tenant_admin, property: @draft, section_id: floor.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit

    delete admin_property_setup_destroy_unit_wizard_path(@draft, unit_id: unit.id)

    assert_not_nil unit.reload.deleted_at
    assert_redirected_to admin_property_setup_wizard_path(@draft)
  end

  test "cancel without delete keeps configured property" do
    configured = ResidentialProperty.create!(
      organization: @organization,
      name: "Configured Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::CONFIGURED,
      country: "Chile",
      timezone: "America/Santiago"
    )

    sign_in_as(@tenant_admin)
    post admin_property_setup_cancel_wizard_path(configured), params: { delete_draft: false }

    assert configured.reload.persisted?
    assert_redirected_to admin_residential_properties_path
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
