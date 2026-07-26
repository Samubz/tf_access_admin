# frozen_string_literal: true

# Contextual detail serializer for unit-scoped owners and residents (§7.5 contextual).
# Exposes visit summary, limited person detail, notes, vehicle metadata, functional
# history, and unit-context permissions (create/authorize/cancel) without full
# administrative actor panels.
class Admin::VisitContextualDetailSerializer < Admin::VisitSerializer
  attributes :notes,
    :metadata,
    :visitor_detail,
    :history,
    :contextual_detail

  def visitor_detail
    limited_person(object.visitor_person)
  end

  def history
    object.visit_status_histories.map do |event|
      Admin::VisitStatusHistorySerializer.new(event).as_json
    end
  end

  def contextual_detail
    true
  end

  def permissions
    @permissions ||= begin
      policy = build_policy
      {
        show: policy.show?,
        create: policy.create?,
        authorize: policy.authorize?,
        cancel: policy.cancel?,
        check_in: policy.check_in?,
        check_out: policy.check_out?,
        full_detail: false,
        restricted_detail: false,
        contextual_detail: policy.contextual_detail?
      }
    end
  end

  private

  def limited_person(person)
    return nil unless person

    {
      id: person.id,
      display_name: person.display_name,
      document_number: person.document_number,
      phone: person.contact_phone
    }
  end
end
