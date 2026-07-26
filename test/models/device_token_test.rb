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
require "test_helper"

class DeviceTokenTest < ActiveSupport::TestCase
  include UserTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @user = create_confirmed_user(email: "device-token-user@example.test")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "a user has at most one device token" do
    DeviceToken.create!(user: @user, token: "token-a", platform: "ios")

    assert_raises(ActiveRecord::RecordNotUnique) do
      DeviceToken.insert!({ user_id: @user.id, token: "token-b", platform: "android" })
    end
  end

  test "registering a new token replaces the previous one for the same user" do
    existing = DeviceToken.create!(user: @user, token: "token-a", platform: "ios")

    upserted = DeviceToken.find_or_initialize_by(user: @user)
    upserted.assign_attributes(token: "token-b", platform: "android")
    upserted.save!

    assert_equal existing.id, upserted.id
    assert_equal "token-b", @user.reload.device_token.token
    assert_equal "android", @user.device_token.platform
  end

  test "platform must be one of the allowed values" do
    device_token = DeviceToken.new(user: @user, token: "token-a", platform: "invalid")

    refute device_token.valid?
    assert_includes device_token.errors[:platform], "is not included in the list"
  end
end
