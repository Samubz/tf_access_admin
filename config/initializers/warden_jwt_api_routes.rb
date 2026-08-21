# frozen_string_literal: true

# devise-jwt merges Devise defaults in an after_initialize hook. Appending to
# jwt.dispatch_requests inside config/initializers/devise.rb runs too early:
# dry-configurable can hand back a temporary Array, so those tuples never stay
# on Warden::JWTAuth.config. Register API login/logout here so they persist.
#
# devise-jwt's own defaults (DefaultsGenerator) also register the Devise HTML
# session routes (POST /users/sign_in, DELETE /users/sign_out) as dispatch
# points because User includes both :database_authenticatable and
# :jwt_authenticatable. Nothing in the app reads that token, and it means
# every HTML login silently signs a JWT it doesn't need. We only want JWTs
# issued for the API login flow, so replace the list instead of appending.
Rails.application.config.after_initialize do
  Warden::JWTAuth.configure do |config|
    config.dispatch_requests = [
      [ "POST", %r{\A/api/v1/auth/login(\.json)?\z} ],
      [ "POST", %r{\A/api/v1/mobile/auth/login(\.json)?\z} ]
    ]
    config.revocation_requests = [
      [ "DELETE", %r{\A/api/v1/auth/logout(\.json)?\z} ],
      [ "DELETE", %r{\A/api/v1/mobile/auth/logout(\.json)?\z} ]
    ]
  end
end
