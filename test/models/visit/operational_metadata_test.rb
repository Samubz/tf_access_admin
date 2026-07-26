# frozen_string_literal: true

require "test_helper"

class Visit::OperationalMetadataTest < ActiveSupport::TestCase
  test "sanitize_metadata keeps only allowed root keys and nested fields" do
    raw = {
      "vehicle" => {
        "plate" => "ABC123",
        "brand_model" => "Honda Civic",
        "color" => "Gray",
        "vin" => "SHOULD_DROP"
      },
      "check_in" => {
        "access_point" => "Main gate",
        "access_type" => VisitAccessTypes::PEDESTRIAN,
        "vehicle_plate" => "ABC123",
        "notes" => "On time",
        "extra" => "drop"
      },
      "check_out" => {
        "access_point" => "Main gate",
        "incident_type" => VisitIncidentTypes::NONE,
        "notes" => "Left quietly",
        "unexpected" => "drop"
      },
      "legacy_key" => "drop"
    }

    sanitized = Visit.sanitize_metadata(raw)

    assert_equal(
      {
        "vehicle" => {
          "plate" => "ABC123",
          "brand_model" => "Honda Civic",
          "color" => "Gray"
        },
        "check_in" => {
          "access_point" => "Main gate",
          "access_type" => VisitAccessTypes::PEDESTRIAN,
          "vehicle_plate" => "ABC123",
          "notes" => "On time"
        },
        "check_out" => {
          "access_point" => "Main gate",
          "incident_type" => VisitIncidentTypes::NONE,
          "notes" => "Left quietly"
        }
      },
      sanitized
    )
  end

  test "merge helpers round-trip allowed metadata on visit instance" do
    visit = Visit.new(metadata: {})

    visit.merge_vehicle_metadata!(
      plate: "XYZ999",
      brand_model: "Toyota Yaris",
      color: "Blue",
      ignored: "value"
    )
    visit.merge_check_in_metadata!(
      access_point: "Side gate",
      access_type: VisitAccessTypes::VEHICLE,
      vehicle_plate: "XYZ999",
      notes: "Arrived by car"
    )
    visit.merge_check_out_metadata!(
      access_point: "Side gate",
      incident_type: VisitIncidentTypes::NONE,
      notes: "Exit ok"
    )

    visit.valid?

    assert_equal "XYZ999", visit.vehicle_metadata["plate"]
    assert_equal VisitAccessTypes::VEHICLE, visit.check_in_metadata["access_type"]
    assert_equal VisitIncidentTypes::NONE, visit.check_out_metadata["incident_type"]
    refute visit.metadata.key?("ignored")
    refute visit.metadata.key?("legacy_key")
  end

  test "blank metadata sections are omitted" do
    sanitized = Visit.sanitize_metadata(
      "vehicle" => { "plate" => "  ", "brand_model" => nil },
      "check_in" => {},
      "check_out" => nil
    )

    assert_equal({}, sanitized)
  end
end
