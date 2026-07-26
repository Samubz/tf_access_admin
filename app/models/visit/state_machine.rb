# frozen_string_literal: true

# AASM lifecycle for MVP visit statuses and transition side effects.
module Visit::StateMachine
  extend ActiveSupport::Concern

  class_methods do
    def terminal_status?(status)
      status.in?([ VisitStatuses::CHECKED_OUT, VisitStatuses::CANCELLED ])
    end
  end

  included do
    include AASM

    aasm column: :status, whiny_transitions: true do
      state :pending, initial: true
      state :authorized
      state :checked_in
      state :checked_out
      state :cancelled
      state :rejected
      state :expired

      event :authorize do
        transitions from: :pending, to: :authorized, after: :stamp_authorization
      end

      event :check_in do
        transitions from: :authorized, to: :checked_in,
                    guard: :within_validity_window?, after: :stamp_check_in
      end

      event :check_out do
        transitions from: :checked_in, to: :checked_out,
                    guard: :exit_not_before_entry?, after: :stamp_check_out
      end

      event :cancel do
        transitions from: %i[pending authorized], to: :cancelled
      end
    end
  end

  def within_validity_window?(*)
    now = Time.zone.now
    return false if valid_from.present? && now < valid_from
    return false if valid_until.present? && now > valid_until

    true
  end

  # 4.6 — A check-out can only happen after a recorded entry. Requires
  # checked_in_at to be present and the effective exit time (now) to not
  # precede it, guarding against clock skew or out-of-order confirmations.
  def exit_not_before_entry?(*)
    return false if checked_in_at.blank?

    Time.zone.now >= checked_in_at
  end

  def assign_initial_status!(actor:, requested_status: nil)
    self.created_by = actor
    resolved = Visit::InitialStatus.resolve(
      actor: actor,
      unit: unit,
      requested_status: requested_status
    )

    if resolved == VisitStatuses::AUTHORIZED
      self.status = VisitStatuses::AUTHORIZED
      stamp_authorization(actor)
    else
      self.status = VisitStatuses::PENDING
    end
  end

  private

  def stamp_authorization(actor)
    ensure_actor!(actor)

    self.authorized_by = actor
    self.authorized_at = Time.zone.now
  end

  def stamp_check_in(actor)
    ensure_actor!(actor)

    self.checked_in_by = actor
    self.checked_in_at = Time.zone.now
  end

  def stamp_check_out(actor)
    ensure_actor!(actor)

    self.checked_out_by = actor
    self.checked_out_at = Time.zone.now
  end

  def ensure_actor!(actor)
    raise ArgumentError, "actor is required for visit transitions" if actor.blank?
  end
end
