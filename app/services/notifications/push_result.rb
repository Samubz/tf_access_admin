# frozen_string_literal: true

module Notifications
  # Shared outcome contract for every push transport (Fcm::Client,
  # ExpoPush::Client). `error_code` is a transport-neutral code such as
  # "DeviceNotRegistered" when the transport reports one, nil otherwise.
  PushResult = Struct.new(:success?, :error_message, :error_code, keyword_init: true)

  class PushResult
    DEVICE_NOT_REGISTERED = "DeviceNotRegistered"

    def device_not_registered?
      error_code == DEVICE_NOT_REGISTERED
    end
  end
end
