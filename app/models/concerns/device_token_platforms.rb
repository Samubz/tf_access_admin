# frozen_string_literal: true

# Allowed +device_tokens.platform+ values (string-backed).
module DeviceTokenPlatforms
  IOS = "ios"
  ANDROID = "android"
  WEB = "web"

  ALL = [ IOS, ANDROID, WEB ].freeze
end
