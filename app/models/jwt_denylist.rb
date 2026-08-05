# frozen_string_literal: true

# == Schema Information
#
# Table name: jwt_denylist
#
#  id  :bigint           not null, primary key
#  exp :datetime         not null
#  jti :string           not null
#
# Indexes
#
#  index_jwt_denylist_on_jti  (jti) UNIQUE
#
class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  self.table_name = "jwt_denylist"

  # Overrides the strategy's default jwt_revoked? to also reject tokens
  # issued before the user's last password change (compared at whole-second
  # precision, matching the JWT `iat` claim), on top of the explicit
  # per-token denylist entries created on logout.
  def self.jwt_revoked?(payload, user)
    return true if exists?(jti: payload["jti"])

    user.password_changed_at.present? && payload["iat"].to_i < user.password_changed_at.to_i
  end
end
