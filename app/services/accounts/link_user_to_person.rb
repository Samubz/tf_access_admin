# frozen_string_literal: true

module Accounts
  # Links a +User+ to a per-organization +Person+, enforcing the cardinality
  # from person-identity: a person has at most one user, and a user has at most
  # one active person per organization. Idempotent for an already-correct link;
  # raises +Conflict+ otherwise. Never touches unit relationships.
  class LinkUserToPerson
    class Conflict < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(person:, user:)
      @person = person
      @user = user
    end

    def call
      return @person if already_linked?

      raise Conflict, "person is already linked to a different user" if @person.user_id.present?
      raise Conflict, "user is already linked to a different person in this organization" if user_linked_elsewhere?

      @person.update!(user: @user)
      @person
    end

    private

    def already_linked?
      @person.user_id.present? && @person.user_id == @user.id
    end

    def user_linked_elsewhere?
      existing = @user.person_for(@person.organization)
      existing.present? && existing.id != @person.id
    end
  end
end
