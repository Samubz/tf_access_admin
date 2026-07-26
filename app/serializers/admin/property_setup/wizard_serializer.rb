# frozen_string_literal: true

class Admin::PropertySetup::WizardSerializer
  def initialize(property:, current_user:, step:, completed: false)
    @property = property
    @current_user = current_user
    @step = step
    @completed = completed
  end

  def as_json
    {
      step: @step,
      completed: @completed,
      property: property_json,
      wizard: Properties::Setup::WizardState.read(@property),
      preview: preview_json,
      property_types: PropertyTypes::ALL,
      section_types: SectionTypes::ALL,
      unit_types: UnitTypes::ALL,
      structure_format: structure_format&.as_json,
      units_in: structure_format&.units_in,
      permissions: permissions_json,
      next_actions: next_actions_json,
      setup: setup_json
    }
  end

  private

  # Whether this edit session is reopening an already-completed property
  # (created/configured/active) — the wizard then only offers manual section
  # and manual unit modes, no quick/automatic generation
  # (enable-wizard-editing-created-state).
  def setup_json
    {
      manual_only: @property.present? && PropertyStatuses::WIZARD_EDITABLE.include?(@property.status),
      configurable: @property.present? && PropertyStatuses::DETAIL_EDITABLE.include?(@property.status)
    }
  end

  def structure_format
    return @structure_format if defined?(@structure_format)

    @structure_format = Properties::Setup::StructureFormatResolver.for(
      property_type: @property&.property_type
    )
  end

  def property_json
    return nil if @property.nil? || !@property.persisted?

    Admin::ResidentialPropertySerializer.new(@property, current_user: @current_user).as_json
  end

  def preview_json
    return {} unless @property&.persisted?

    Properties::Setup::BuildPreview.call(property: @property, actor: @current_user)
  end

  def permissions_json
    policy = ResidentialPropertyPolicy.new(@current_user, @property || ResidentialProperty.new)
    unit_policy = UnitPolicy.new(@current_user, Unit)

    {
      manage_setup: policy.create?,
      activate: @property&.status == PropertyStatuses::CONFIGURED && policy.update?,
      manage_units: @property.present? && unit_policy.property_allowed?(:manage_units, property: @property)
    }
  end

  def next_actions_json
    Properties::Setup::NextActions.call(property: @property, actor: @current_user)
  end
end
