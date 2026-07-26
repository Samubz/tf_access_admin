# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :organization
  attribute :user
  attribute :person
  attribute :authorization_grant_profile

  def self.authorization_resolver(property: nil, unit: nil, record: nil)
    return nil if user.blank? || organization.blank?

    profile = authorization_grant_profile.presence || begin
      built = Authorization::GrantProfile.build(user, organization)
      self.authorization_grant_profile = built
      built
    end

    Authorization::Resolver.new(
      user: user,
      organization: organization,
      property: property,
      unit: unit,
      record: record,
      profile: profile
    )
  end
end
