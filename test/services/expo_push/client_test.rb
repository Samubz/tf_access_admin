# frozen_string_literal: true

require "test_helper"

module ExpoPush
  class ClientTest < ActiveSupport::TestCase
    SEND_URL = "https://exp.host/--/api/v2/push/send"

    test "sends the Expo request shape and reports success" do
      stub_request(:post, SEND_URL).to_return(status: 200, body: { data: { status: "ok", id: "abc" } }.to_json)

      client = Client.new(base_url: "https://exp.host", access_token: nil)
      result = client.send_notification(
        token: "ExponentPushToken[abc]",
        title: "Hi",
        body: "There",
        data: { visit_id: "123" }
      )

      assert result.success?
      assert_nil result.error_message
      assert_nil result.error_code
      assert_requested(:post, SEND_URL, headers: { "Accept" => "application/json", "Content-Type" => "application/json" }) do |request|
        payload = JSON.parse(request.body)
        payload["to"] == "ExponentPushToken[abc]" &&
          payload["title"] == "Hi" &&
          payload["body"] == "There" &&
          payload["data"] == { "visit_id" => "123" } &&
          payload["sound"] == "default" &&
          request.headers["Authorization"].nil?
      end
    end

    test "includes an Authorization header when an access_token is configured" do
      stub_request(:post, SEND_URL).to_return(status: 200, body: { data: { status: "ok" } }.to_json)

      Client.new(base_url: "https://exp.host", access_token: "secret").send_notification(token: "t", title: "T", body: "B")

      assert_requested(:post, SEND_URL, headers: { "Authorization" => "Bearer secret" })
    end

    test "uses EXPO_PUSH_BASE_URL when set" do
      stub = stub_request(:post, "http://expo.local:8091/--/api/v2/push/send")
        .to_return(status: 200, body: { data: { status: "ok" } }.to_json)

      with_env("EXPO_PUSH_BASE_URL", "http://expo.local:8091") do
        Client.new(access_token: nil).send_notification(token: "t", title: "T", body: "B")
      end

      assert_requested(stub)
    end

    test "an error ticket returns a failed result with the error code" do
      stub_request(:post, SEND_URL).to_return(
        status: 200,
        body: { data: { status: "error", message: "not registered", details: { error: "DeviceNotRegistered" } } }.to_json
      )

      result = Client.new(access_token: nil).send_notification(token: "t", title: "T", body: "B")

      refute result.success?
      assert_equal "DeviceNotRegistered", result.error_code
      assert_match(/not registered/, result.error_message)
    end

    test "tolerates data returned as an array of tickets" do
      stub_request(:post, SEND_URL).to_return(
        status: 200,
        body: { data: [ { status: "error", message: "gone", details: { error: "DeviceNotRegistered" } } ] }.to_json
      )

      result = Client.new(access_token: nil).send_notification(token: "t", title: "T", body: "B")

      refute result.success?
      assert_equal "DeviceNotRegistered", result.error_code
    end

    test "a non-2xx response returns a failed result without raising" do
      stub_request(:post, SEND_URL).to_return(status: 500, body: "boom")

      result = Client.new(access_token: nil).send_notification(token: "t", title: "T", body: "B")

      refute result.success?
      assert_match(/500/, result.error_message)
      assert_nil result.error_code
    end

    test "a connection error returns a failed result without raising" do
      stub_request(:post, SEND_URL).to_raise(Errno::ECONNREFUSED)

      result = Client.new(access_token: nil).send_notification(token: "t", title: "T", body: "B")

      refute result.success?
      assert result.error_message.present?
      assert_nil result.error_code
    end

    private

    def with_env(key, value)
      original = ENV[key]
      ENV[key] = value
      yield
    ensure
      ENV[key] = original
    end
  end
end
