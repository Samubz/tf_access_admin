# frozen_string_literal: true

# Shared `authorizers` attribute for Visit serializers: the unit's current
# active residents with can_authorize_visits: true, computed live (not a
# per-visit snapshot). Replaces the removed single "host" concept — see
# openspec/changes/remove-visit-host-use-unit-authorizers.
module VisitAuthorizersSerialization
  def authorizers
    unit = object.unit
    return [] unless unit

    UnitOccupancy.active_authorizers_for(unit).includes(:person).map do |occupancy|
      { id: occupancy.person.id, display_name: occupancy.person.display_name }
    end
  end
end
