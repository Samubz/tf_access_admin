# frozen_string_literal: true

class Person::ProfileSummary
  def self.for(person)
    new(person).to_h
  end

  def initialize(person)
    @person = person
  end

  def to_h
    {
      active_ownerships_count: active_ownerships_count,
      active_occupancies_count: active_occupancies_count,
      visits_count: 0,
      staff_assignments_count: 0
    }
  end

  private

  def active_ownerships_count
    @person.unit_ownerships.where(status: UnitOwnership::STATUS_ACTIVE).count
  end

  def active_occupancies_count
    @person.unit_occupancies.where(status: OccupancyStatuses::ACTIVE).count
  end
end
