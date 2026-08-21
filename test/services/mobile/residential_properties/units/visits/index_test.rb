# frozen_string_literal: true

require "test_helper"

module Mobile
  module ResidentialProperties
    module Units
      module Visits
        class IndexTest < ActiveSupport::TestCase
          setup do
            @organization = organizations(:one)
            @user = create_user_for_organization(
              organization: @organization,
              email: "rp-visits@example.com",
              role: AvailableRoles::CLIENT
            )
            @person = ActsAsTenant.with_tenant(@organization) { @user.person_for(@organization) }
            @property = create_property!(status: PropertyStatuses::ACTIVE)
            @unit = create_unit!(property: @property, status: UnitStatuses::AVAILABLE)
          end

          test "returns today's visit by default in the property's timezone" do
            occupy_unit!
            zone = ActiveSupport::TimeZone[@property.timezone]
            visit = create_visit!(scheduled_at: zone.now.change(hour: 12))

            result = call

            assert_equal 1, result.size
            entry = result.first
            assert_equal visit.visitor_person.display_name, entry[:visitor_name]
            assert_nil entry[:checked_in_at]
            assert_nil entry[:checked_out_at]
            assert_equal visit.status, entry[:status]
          end

          test "returns visits for an explicit day" do
            occupy_unit!
            zone = ActiveSupport::TimeZone[@property.timezone]
            target_day = zone.today + 3
            visit = create_visit!(scheduled_at: zone.local(target_day.year, target_day.month, target_day.day, 10))
            create_visit!(scheduled_at: zone.now.change(hour: 12))

            result = call(day: target_day.iso8601)

            assert_equal 1, result.size
            assert_equal visit.visitor_person.display_name, result.first[:visitor_name]
          end

          test "day boundary is computed in the property's timezone, not UTC" do
            occupy_unit!
            zone = ActiveSupport::TimeZone[@property.timezone]
            local_late_night = zone.local(zone.today.year, zone.today.month, zone.today.day, 23, 30)
            visit = create_visit!(scheduled_at: local_late_night)

            result_local_day = call(day: zone.today.iso8601)

            assert_equal 1, result_local_day.size
            assert_equal visit.visitor_person.display_name, result_local_day.first[:visitor_name]

            if local_late_night.utc.to_date != zone.today
              result_utc_day = call(day: local_late_night.utc.to_date.iso8601)
              assert_equal 0, result_utc_day.size
            end
          end

          test "malformed day returns :invalid_day" do
            occupy_unit!

            result = call(day: "not-a-date")

            assert_equal :invalid_day, result
          end

          test "includes all visit statuses with no filtering" do
            occupy_unit!
            zone = ActiveSupport::TimeZone[@property.timezone]
            statuses = [
              VisitStatuses::PENDING, VisitStatuses::AUTHORIZED, VisitStatuses::CHECKED_IN,
              VisitStatuses::CHECKED_OUT, VisitStatuses::CANCELLED, VisitStatuses::REJECTED, VisitStatuses::EXPIRED
            ]
            statuses.each_with_index do |status, i|
              create_visit!(scheduled_at: zone.now.change(hour: 1) + i.hours, status: status)
            end

            result = call

            assert_equal statuses.size, result.size
            assert_equal statuses.sort, result.map { |e| e[:status] }.sort
          end

          test "returns empty array when no visits scheduled that day" do
            occupy_unit!

            result = call

            assert_equal [], result
          end

          test "returns nil for owner without active occupancy" do
            own_unit!

            assert_nil call
          end

          test "returns nil for inactive occupancy" do
            occupy_unit!(status: OccupancyStatuses::INACTIVE)

            assert_nil call
          end

          test "returns nil for nonexistent residential property id" do
            result = Index.call(user: @user, residential_property_id: SecureRandom.uuid, unit_id: @unit.id)

            assert_nil result
          end

          test "returns nil for nonexistent unit id or unit belonging to a different property" do
            occupy_unit!
            other_property = create_property!(status: PropertyStatuses::ACTIVE)
            other_unit = create_unit!(property: other_property, status: UnitStatuses::AVAILABLE)

            result = Index.call(
              user: @user, residential_property_id: @property.id, unit_id: other_unit.id
            )

            assert_nil result
          end

          test "returns nil when residential property is not active" do
            inactive_property = create_property!(status: PropertyStatuses::INACTIVE)
            unit = create_unit!(property: inactive_property, status: UnitStatuses::AVAILABLE)
            ActsAsTenant.with_tenant(@organization) do
              UnitOccupancy.create!(
                organization: @organization, unit: unit, person: @person,
                occupancy_type: OccupancyTypes::TENANT, status: OccupancyStatuses::ACTIVE, starts_at: Time.current
              )
            end

            result = Index.call(user: @user, residential_property_id: inactive_property.id, unit_id: unit.id)

            assert_nil result
          end

          test "returns nil when unit has an ineligible status" do
            occupy_unit!
            @unit.update!(status: UnitStatuses::MAINTENANCE)

            assert_nil call
          end

          private

          def call(day: nil)
            Index.call(user: @user, residential_property_id: @property.id, unit_id: @unit.id, day: day)
          end

          def own_unit!
            ActsAsTenant.with_tenant(@organization) do
              UnitOwnership.create!(
                organization: @organization, unit: @unit, person: @person,
                ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
              )
            end
          end

          def occupy_unit!(status: OccupancyStatuses::ACTIVE)
            ActsAsTenant.with_tenant(@organization) do
              UnitOccupancy.create!(
                organization: @organization, unit: @unit, person: @person,
                occupancy_type: OccupancyTypes::TENANT, status: status, starts_at: Time.current
              )
            end
          end

          def create_visit!(scheduled_at:, status: VisitStatuses::PENDING)
            ActsAsTenant.with_tenant(@organization) do
              visitor = Person.create!(
                organization: @organization,
                display_name: "Visitor #{SecureRandom.hex(4)}",
                person_type: PersonTypes::NATURAL,
                status: PersonStatuses::ACTIVE
              )
              Visit.create!(
                organization: @organization,
                unit: @unit,
                visitor_person: visitor,
                scheduled_at: scheduled_at,
                valid_from: scheduled_at,
                status: status,
                visit_type: VisitTypes::GUEST
              )
            end
          end

          def create_property!(status:)
            ActsAsTenant.with_tenant(@organization) do
              ResidentialProperty.create!(
                organization: @organization,
                name: "RP Visits Test #{SecureRandom.hex(4)}",
                property_type: PropertyTypes::BUILDING,
                status: status,
                country: "Chile",
                timezone: "America/Santiago"
              )
            end
          end

          def create_unit!(property:, status:)
            ActsAsTenant.with_tenant(@organization) do
              Unit.create!(
                organization: @organization,
                residential_property: property,
                identifier: "RP-VISITS-#{SecureRandom.hex(4)}",
                unit_type: UnitTypes::APARTMENT,
                status: status
              )
            end
          end
        end
      end
    end
  end
end
