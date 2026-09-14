# frozen_string_literal: true

module Notifications
  # Picks the push transport for a device token based on its format:
  # Expo tokens (`ExponentPushToken[...]`) go through the Expo Push Service,
  # anything else through FCM (see design.md D7).
  module PushTransport
    EXPO_TOKEN_PREFIX = "ExponentPushToken["

    def self.for(token)
      if token.to_s.start_with?(EXPO_TOKEN_PREFIX)
        ExpoPush::Client.new
      else
        Fcm::Client.new
      end
    end
  end
end
