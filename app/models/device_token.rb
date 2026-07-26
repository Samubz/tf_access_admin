# frozen_string_literal: true

# == Schema Information
#
# Table name: device_tokens
#
#  id           :uuid             not null, primary key
#  last_seen_at :datetime
#  platform     :string           not null
#  token        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :uuid             not null
#
# Indexes
#
#  index_device_tokens_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
# A +User+ has at most one registered device token at a time (product decision:
# one device per user; registering a new token replaces the previous one). See
# openspec/changes/add-fcm-push-notifications/design.md Decision 2.
class DeviceToken < ApplicationRecord
  include DeviceTokenPlatforms

  belongs_to :user

  validates :token, presence: true
  validates :platform, presence: true, inclusion: { in: DeviceTokenPlatforms::ALL }
end
