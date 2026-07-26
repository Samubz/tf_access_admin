# frozen_string_literal: true

# Full detail serializer for Visit (§7.5).
# Used in Admin::VisitsController#show, #new, #edit when policy.full_detail? is true.
# Extends Admin::VisitSerializer with complete person profiles, actor stamps,
# notes, metadata, and the functional event history (§7.8).
class Admin::VisitDetailSerializer < Admin::VisitSerializer
  attributes :notes,
    :metadata,
    :property_section_id,
    :created_by_id,
    :authorized_by_id,
    :checked_in_by_id,
    :checked_out_by_id,
    :visitor_detail,
    :unit_detail,
    :created_by_actor,
    :authorized_by_actor,
    :checked_in_by_actor,
    :checked_out_by_actor,
    :history

  def visitor_detail
    full_person(object.visitor_person)
  end

  def unit_detail
    u = object.unit
    return nil unless u

    {
      id: u.id,
      identifier: u.identifier,
      display_name: u.display_name,
      residential_property_id: u.residential_property_id,
      property_section_id: u.property_section_id
    }
  end

  def created_by_actor
    actor_summary(object.created_by)
  end

  def authorized_by_actor
    actor_summary(object.authorized_by)
  end

  def checked_in_by_actor
    actor_summary(object.checked_in_by)
  end

  def checked_out_by_actor
    actor_summary(object.checked_out_by)
  end

  def history
    object.visit_status_histories.map do |event|
      Admin::VisitStatusHistorySerializer.new(event).as_json
    end
  end

  private

  def full_person(person)
    return nil unless person

    {
      id: person.id,
      display_name: person.display_name,
      first_name: person.first_name,
      last_name: person.last_name,
      person_type: person.person_type,
      document_type: person.document_type,
      document_number: person.document_number,
      email: person.contact_email,
      phone: person.contact_phone
    }
  end

  def actor_summary(user)
    return nil unless user

    { id: user.id, name: user.name, email: user.email }
  end
end
