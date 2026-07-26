require_relative "production"

Rails.application.configure do
  if ENV["MAIL_DELIVERY_MODE"] == "mailhog"
    config.action_mailer.delivery_method = :smtp

    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS", "mailhog"),
      port: ENV.fetch("SMTP_PORT", 1025).to_i,
      authentication: nil,
      enable_starttls_auto: false
    }

    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true

    config.action_mailer.default_url_options = {
      host: ENV.fetch("APP_HOST"),
      protocol: "https"
    }
  end
end
