# frozen_string_literal: true

module Api
  module Private
    # Active unit relationships of a Person within an organization, resolved once
    # and shared by the private API serializers (isOwner / occupancyType flags).
    class ResidentRelationships
      def initialize(person:, organization:)
        @person = person
        @organization = organization
      end

      def units
        Unit.with_active_relationship_for(@person, @organization)
      end

      def residential_properties
        ResidentialProperty.where(id: units.select(:residential_property_id)).order(:name)
      end

      def owner?(unit)
        ownership_unit_ids.include?(unit.id)
      end

      def occupancy_type_for(unit)
        occupancy_types_by_unit[unit.id]
      end

      private

      def ownership_unit_ids
        @ownership_unit_ids ||= Authorization::ActiveRelationships
          .active_ownerships_for(@person, @organization).pluck(:unit_id).to_set
      end

      def occupancy_types_by_unit
        @occupancy_types_by_unit ||= Authorization::ActiveRelationships
          .active_occupancies_for(@person, @organization).pluck(:unit_id, :occupancy_type).to_h
      end
    end
  end
end
