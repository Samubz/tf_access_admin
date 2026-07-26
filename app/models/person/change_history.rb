# frozen_string_literal: true

class Person::ChangeHistory
  DEFAULT_LIMIT = 25

  ENTRY = Struct.new(
    :id,
    :occurred_at,
    :description,
    :actor_name,
    :tone,
    :source_type,
    :source_id,
    keyword_init: true
  )

  def self.for(person, limit: DEFAULT_LIMIT)
    new(person, limit: limit).entries
  end

  def initialize(person, limit: DEFAULT_LIMIT)
    @person = person
    @limit = limit
  end

  def entries
    audits.map { |audit| build_entry(audit) }.compact.map(&:to_h)
  end

  private

  def audits
    @audits ||= begin
      base = TenantAudit.where(organization_id: @person.organization_id)
      relation = base.where(auditable_type: "Person", auditable_id: @person.id)

      if ownership_ids.any?
        relation = relation.or(
          base.where(auditable_type: "UnitOwnership", auditable_id: ownership_ids)
        )
      end

      if occupancy_ids.any?
        relation = relation.or(
          base.where(auditable_type: "UnitOccupancy", auditable_id: occupancy_ids)
        )
      end

      relation
        .order(created_at: :desc)
        .limit(@limit)
        .includes(:user)
        .to_a
    end
  end

  def ownership_ids
    @ownership_ids ||= @person.unit_ownerships.with_deleted.pluck(:id)
  end

  def occupancy_ids
    @occupancy_ids ||= @person.unit_occupancies.with_deleted.pluck(:id)
  end

  def build_entry(audit)
    context = preload_context
    description = description_for(audit, context)
    return if description.blank?

    ENTRY.new(
      id: audit.id,
      occurred_at: audit.created_at.iso8601,
      description: description,
      actor_name: actor_name_for(audit),
      tone: tone_for(audit),
      source_type: audit.auditable_type,
      source_id: audit.auditable_id
    )
  end

  def preload_context
    @preload_context ||= begin
      ownership_ids = []
      occupancy_ids = []
      person_ids = Set.new([ @person.id ])

      audits.each do |audit|
        case audit.auditable_type
        when "UnitOwnership"
          ownership_ids << audit.auditable_id
          collect_ids_from_changes(audit.audited_changes, :person_id, person_ids)
        when "UnitOccupancy"
          occupancy_ids << audit.auditable_id
          collect_ids_from_changes(audit.audited_changes, :person_id, person_ids)
        end
      end

      ownerships = UnitOwnership.with_deleted
        .where(id: ownership_ids)
        .includes(:person)
        .index_by(&:id)
      occupancies = UnitOccupancy.with_deleted
        .where(id: occupancy_ids)
        .includes(:person)
        .index_by(&:id)

      {
        people: Person.with_deleted.where(id: person_ids.to_a).index_by(&:id),
        ownerships: ownerships,
        occupancies: occupancies
      }
    end
  end

  def collect_ids_from_changes(changes, attribute, bucket)
    return unless changes.is_a?(Hash)

    Array(changes[attribute.to_s] || changes[attribute.to_sym]).each do |value|
      bucket << value if value.present?
    end
  end

  def description_for(audit, context)
    case audit.auditable_type
    when "Person"
      person_description(audit)
    when "UnitOwnership"
      ownership_description(audit, context)
    when "UnitOccupancy"
      occupancy_description(audit, context)
    end
  end

  def person_description(audit)
    actor = actor_name_for(audit)

    case audit.action
    when "create"
      t("events.person_created", actor:)
    when "update"
      changes = audit.audited_changes.to_h
      if changes.key?("status") || changes.key?(:status)
        _, to = Array(changes["status"] || changes[:status])
        return t("events.person_status_changed", actor:, to: format_person_status(to))
      end

      t("events.person_updated", actor:)
    when "destroy"
      t("events.person_removed", actor:)
    end
  end

  def ownership_description(audit, context)
    actor = actor_name_for(audit)
    ownership = context[:ownerships][audit.auditable_id]
    person_name = person_for(audit, ownership, context)

    case audit.action
    when "create"
      percentage = ownership&.ownership_percentage || audit.audited_changes.to_h.dig("ownership_percentage", 1)
      unit_history_t(
        "events.ownership_created",
        actor:,
        person: person_name,
        percentage: format_percentage(percentage)
      )
    when "update"
      changes = audit.audited_changes.to_h

      if changes.key?("ownership_percentage") || changes.key?(:ownership_percentage)
        from, to = Array(changes["ownership_percentage"] || changes[:ownership_percentage])
        return unit_history_t(
          "events.ownership_percentage_changed",
          actor:,
          person: person_name,
          from: format_percentage(from),
          to: format_percentage(to)
        )
      end

      if changes.key?("status") || changes.key?(:status)
        _, to = Array(changes["status"] || changes[:status])
        return unit_history_t("events.ownership_status_changed", actor:, person: person_name, to: format_ownership_status(to))
      end

      unit_history_t("events.ownership_updated", actor:, person: person_name)
    when "destroy"
      unit_history_t("events.ownership_removed", actor:, person: person_name)
    end
  end

  def occupancy_description(audit, context)
    actor = actor_name_for(audit)
    occupancy = context[:occupancies][audit.auditable_id]
    person_name = person_for_occupancy(audit, occupancy, context)

    case audit.action
    when "create"
      occupancy_type = occupancy&.occupancy_type || Array(audit.audited_changes.to_h["occupancy_type"]).last
      unit_history_t(
        "events.occupancy_created",
        actor:,
        person: person_name,
        type: format_occupancy_type(occupancy_type)
      )
    when "update"
      changes = audit.audited_changes.to_h

      if changes.key?("occupancy_type") || changes.key?(:occupancy_type)
        _, to = Array(changes["occupancy_type"] || changes[:occupancy_type])
        return unit_history_t("events.occupancy_type_changed", actor:, person: person_name, to: format_occupancy_type(to))
      end

      if changes.key?("status") || changes.key?(:status)
        _, to = Array(changes["status"] || changes[:status])
        return unit_history_t("events.occupancy_status_changed", actor:, person: person_name, to: format_occupancy_status(to))
      end

      if changes.key?("can_authorize_visits") || changes.key?(:can_authorize_visits)
        _, to = Array(changes["can_authorize_visits"] || changes[:can_authorize_visits])
        return unit_history_t(
          "events.occupancy_authorization_changed",
          actor:,
          person: person_name,
          to: format_boolean(to)
        )
      end

      unit_history_t("events.occupancy_updated", actor:, person: person_name)
    when "destroy"
      unit_history_t("events.occupancy_removed", actor:, person: person_name)
    end
  end

  def person_for(audit, ownership, context)
    changes = audit.audited_changes.to_h
    person_id = ownership&.person_id || Array(changes["person_id"] || changes[:person_id]).last
    context[:people][person_id]&.display_name || unit_history_t("events.unknown_person")
  end

  def person_for_occupancy(audit, occupancy, context)
    changes = audit.audited_changes.to_h
    person_id = occupancy&.person_id || Array(changes["person_id"] || changes[:person_id]).last
    context[:people][person_id]&.display_name || unit_history_t("events.unknown_occupant")
  end

  def actor_name_for(audit)
    audit.user&.name.presence || audit.username.presence || t("actor_fallback")
  end

  def tone_for(audit)
    return "success" if audit.action == "create"
    return "warning" if audit.action == "destroy" || status_changed?(audit)

    "neutral"
  end

  def status_changed?(audit)
    changes = audit.audited_changes.to_h
    changes.key?("status") || changes.key?(:status)
  end

  def format_person_status(status)
    I18n.t(
      "frontend.admin.people.statuses.#{status}",
      default: status.to_s.humanize
    )
  end

  def format_ownership_status(status)
    unit_history_t("ownership_statuses.#{status}", default: status.to_s.humanize)
  end

  def format_occupancy_status(status)
    unit_history_t("occupancy_statuses.#{status}", default: status.to_s.humanize)
  end

  def format_occupancy_type(occupancy_type)
    return unit_history_t("events.blank_value") if occupancy_type.blank?

    I18n.t(
      "frontend.admin.unit_occupancies.occupancy_types.#{occupancy_type}",
      default: occupancy_type.to_s.humanize
    )
  end

  def format_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) ? unit_history_t("events.boolean_yes") : unit_history_t("events.boolean_no")
  end

  def format_percentage(value)
    return "—" if value.blank?

    number = value.to_d
    formatted = number.frac.zero? ? number.to_i.to_s : number.round(1).to_s
    "#{formatted}%"
  end

  def t(key, **options)
    I18n.t("frontend.admin.people.profile.change_history.#{key}", **options)
  end

  def unit_history_t(key, **options)
    I18n.t("frontend.admin.units.show.change_history.#{key}", **options)
  end
end
