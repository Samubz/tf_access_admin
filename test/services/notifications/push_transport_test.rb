# frozen_string_literal: true

require "test_helper"

module Notifications
  class PushTransportTest < ActiveSupport::TestCase
    test "an Expo token selects the Expo Push client" do
      assert_instance_of ExpoPush::Client, PushTransport.for("ExponentPushToken[abc]")
    end

    test "any other token selects the FCM client" do
      assert_instance_of Fcm::Client, PushTransport.for("fcm-device-token")
    end
  end
end
