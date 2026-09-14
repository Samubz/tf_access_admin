# frozen_string_literal: true

module Residents
  # Resolves or creates the visitor Person for a resident-initiated visit (3.x).
  #
  # Adapter between the resident private API payload and the canonical visitor
  # resolution service. The resident API submits a flat visitor object:
  #
  #   { "name" => "...", "email" => "...", "document" => "...", "phone" => "..." }
  #
  # This service translates those keys and delegates to
  # +Visits::ResolveVisitorPerson+ which uses +People::FindExisting+ (document
  # digest, org-scoped) as the canonical lookup strategy.
  #
  # Contract:
  #   D3 — lookup order: document digest (if provided) → normalized email digest
  #        (downcase/strip) → create with display_name, email, phone, document.
  #        Both lookups are scoped by organization_id (no cross-org reuse).
  #        A document match with a different stored email raises
  #        Visits::ResolveVisitorPerson::IdentityConflict; persons are never merged.
  #
  # Usage:
  #   person = Residents::ResolveVisitorPerson.call(
  #     organization: current_organization,
  #     visitor_params: params[:visitor]
  #   )
  class ResolveVisitorPerson
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, visitor_params:)
      @organization    = organization
      @visitor_params  = visitor_params.to_h.symbolize_keys
    end

    # Returns the resolved or newly created visitor Person.
    # Delegates to Visits::ResolveVisitorPerson for canonical find-or-create.
    def call
      Visits::ResolveVisitorPerson.call(
        organization: @organization,
        person_params: adapted_params
      )
    end

    private

    # Translates the resident API visitor payload to the param keys expected
    # by Visits::ResolveVisitorPerson / People::FindExisting.
    def adapted_params
      {
        document_number: @visitor_params[:document].to_s.strip.presence,
        display_name:    @visitor_params[:name].to_s.strip.presence,
        email:           @visitor_params[:email].to_s.downcase.strip.presence,
        phone:           @visitor_params[:phone].to_s.strip.presence,
        person_type:     PersonTypes::NATURAL
      }
    end
  end
end
