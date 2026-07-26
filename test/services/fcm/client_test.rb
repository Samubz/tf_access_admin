# frozen_string_literal: true

require "test_helper"
require "socket"

module Fcm
  # No HTTP mocking library exists in this project's bundle (no webmock/mocha,
  # and minitest/mock is unavailable in this Rails 8.1 + minitest 6 setup), so
  # these tests spin up a tiny real TCP server to capture the outgoing request
  # and return a canned response.
  class ClientTest < ActiveSupport::TestCase
    test "sends the Firebase HTTP v1 request shape and reports success" do
      with_fake_server(status_line: "200 OK", body: "{}") do |base_url, captured|
        client = Client.new(base_url: base_url, project_id: "test-project", auth_token: nil)

        result = client.send_notification(
          token: "device-token",
          title: "Hi",
          body: "There",
          data: { visit_id: "123" }
        )

        assert result.success?
        assert_nil result.error_message

        request = captured.call
        assert_match %r{\APOST /v1/projects/test-project/messages:send}, request[:request_line]
        payload = JSON.parse(request[:body])
        assert_equal "device-token", payload.dig("message", "token")
        assert_equal "Hi", payload.dig("message", "notification", "title")
        assert_equal "There", payload.dig("message", "notification", "body")
        assert_equal "123", payload.dig("message", "data", "visit_id")
      end
    end

    test "includes an Authorization header when an auth_token is configured" do
      with_fake_server(status_line: "200 OK", body: "{}") do |base_url, captured|
        client = Client.new(base_url: base_url, project_id: "test-project", auth_token: "secret-token")
        client.send_notification(token: "t", title: "T", body: "B")

        request = captured.call
        assert_equal "Bearer secret-token", request[:headers]["Authorization"]
      end
    end

    test "a non-2xx response returns a failed result without raising" do
      with_fake_server(status_line: "500 Internal Server Error", body: "boom") do |base_url, _captured|
        client = Client.new(base_url: base_url, project_id: "test-project")

        result = client.send_notification(token: "t", title: "T", body: "B")

        refute result.success?
        assert_match(/500/, result.error_message)
      end
    end

    test "a connection error returns a failed result without raising" do
      unreachable_server = TCPServer.new("127.0.0.1", 0)
      port = unreachable_server.addr[1]
      unreachable_server.close

      client = Client.new(base_url: "http://127.0.0.1:#{port}", project_id: "test-project")

      result = client.send_notification(token: "t", title: "T", body: "B")

      refute result.success?
      assert result.error_message.present?
    end

    private

    def with_fake_server(status_line:, body:)
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      captured = nil

      thread = Thread.new do
        connection = server.accept
        request_line = connection.gets
        headers = {}
        while (line = connection.gets) && line != "\r\n"
          key, value = line.split(":", 2)
          headers[key.strip] = value.strip if value
        end
        content_length = headers["Content-Length"].to_i
        request_body = content_length.positive? ? connection.read(content_length) : ""
        captured = { request_line: request_line, headers: headers, body: request_body }
        connection.write("HTTP/1.1 #{status_line}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        connection.close
      end

      yield("http://127.0.0.1:#{port}", -> { thread.join(2); captured })
    ensure
      server&.close
    end
  end
end
