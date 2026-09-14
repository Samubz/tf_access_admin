# frozen_string_literal: true

require "net/http"
require "json"

module ExpoPush
  # Thin HTTP client for the Expo Push Service send endpoint.
  #
  # Points at a configurable base URL (EXPO_PUSH_BASE_URL) so development can
  # redirect delivery to a local simulator, defaulting to the real Expo host.
  # An optional access token (credentials `expo.access_token`) is sent as a
  # Bearer header when present.
  #
  # IMPORTANT: #send_notification NEVER raises — it always returns a
  # Notifications::PushResult, for the same reasons as Fcm::Client (the job
  # relies on reaching its bookkeeping exactly once per attempt).
  class Client
    Result = Notifications::PushResult

    def initialize(
      base_url: ENV.fetch("EXPO_PUSH_BASE_URL", "https://exp.host"),
      access_token: Rails.application.credentials.dig(:expo, :access_token)
    )
      @base_url = base_url
      @access_token = access_token
    end

    def send_notification(token:, title:, body:, data: {})
      uri = URI.parse("#{@base_url}/--/api/v2/push/send")
      request = build_request(uri, token:, title:, body:, data:)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        result_from_ticket(parse_ticket(response.body))
      else
        Result.new(success?: false, error_message: "Expo responded with #{response.code}: #{response.body}")
      end
    rescue StandardError => e
      Result.new(success?: false, error_message: e.message)
    end

    private

    def build_request(uri, token:, title:, body:, data:)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@access_token}" if @access_token.present?
      request.body = { to: token, title:, body:, data:, sound: "default" }.to_json
      request
    end

    # Expo returns `data` as a single ticket for a single message, but as an
    # array when the request body was itself an array — accept both.
    def parse_ticket(body)
      data = JSON.parse(body)["data"]
      data = data.first if data.is_a?(Array)
      data.is_a?(Hash) ? data : {}
    end

    def result_from_ticket(ticket)
      return Result.new(success?: true) if ticket["status"] == "ok"

      Result.new(
        success?: false,
        error_message: "Expo push error: #{ticket['message'].presence || ticket.to_json}",
        error_code: ticket.dig("details", "error")
      )
    end
  end
end
