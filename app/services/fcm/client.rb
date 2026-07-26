# frozen_string_literal: true

require "net/http"
require "json"

module Fcm
  # Thin HTTP client for the Firebase Cloud Messaging HTTP v1 send endpoint.
  #
  # Points at a configurable base URL (FCM_BASE_URL) so development can redirect
  # delivery to a local FCM-compatible simulator (e.g. PushHog) without code
  # changes, while defaulting to the real Firebase endpoint everywhere else.
  #
  # IMPORTANT: #send_notification NEVER raises for a delivery failure (connection
  # error or non-2xx response) — it always returns a Result. Callers (namely
  # DeliverPushNotificationJob) rely on this to reach their own post-delivery
  # bookkeeping exactly once per attempt; a raised exception here would abort
  # that bookkeeping and leave the Notification/Visit#notification_status
  # rollup in a stale state (see design.md Decision 4/5/7).
  class Client
    Result = Struct.new(:success?, :error_message, keyword_init: true)

    def initialize(
      base_url: ENV.fetch("FCM_BASE_URL", "https://fcm.googleapis.com"),
      project_id: ENV.fetch("FCM_PROJECT_ID", "development"),
      auth_token: Rails.application.credentials.dig(:fcm, :auth_token)
    )
      @base_url = base_url
      @project_id = project_id
      @auth_token = auth_token
    end

    def send_notification(token:, title:, body:, data: {})
      uri = URI.parse("#{@base_url}/v1/projects/#{@project_id}/messages:send")
      request = build_request(uri, token:, title:, body:, data:)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        Result.new(success?: true, error_message: nil)
      else
        Result.new(success?: false, error_message: "FCM responded with #{response.code}: #{response.body}")
      end
    rescue StandardError => e
      Result.new(success?: false, error_message: e.message)
    end

    private

    def build_request(uri, token:, title:, body:, data:)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@auth_token}" if @auth_token.present?
      request.body = {
        message: {
          token:,
          notification: { title:, body: },
          data: data.transform_values(&:to_s)
        }
      }.to_json
      request
    end
  end
end
