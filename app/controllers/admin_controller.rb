# frozen_string_literal: true

class AdminController < InertiaController
  include PaginationProps
  include InertiaErrorsSerializable

  before_action :authenticate_user!
  before_action :set_locale
  # Usar `if:` en lugar de `only:` para no exigir la acción `index` en hijos sin esa acción
  # (p. ej. Devise::SessionsController), con raise_on_missing_callback_actions en Rails 7.1+.
  before_action :set_filters, if: -> { action_name == "index" }

  inertia_share auth: -> {
    if user_signed_in?
      { user: Admin::UserSerializer.new(current_user).as_json, features: current_user.features }
    else
      {}
    end
  }
  # Expose the current user's effective capabilities to the frontend.
  # Keys are snake_case capability names; value is true when the user has
  # that capability in the current organization context (org-wide OR in at
  # least one accessible property). Used for conditional nav rendering and
  # UI feature flags. Never used for authorization — that always happens in
  # Pundit policies on the server side.
  inertia_share capabilities: -> {
    resolve_current_capabilities
  }
  # Share data with all Inertia responses, this is used to pass the locale and translations to the client
  inertia_share app: -> {
    effective_locale = current_user&.language.presence || I18n.locale.to_s
    {
      locale: effective_locale,
      available_locales: I18n.available_locales.map(&:to_s),
      translations: frontend_translations(effective_locale)
    }
  }

  private

  # Set the locale for the user
  def set_locale
    I18n.locale =
      current_user&.language.presence ||
      params[:locale].presence ||
      session[:locale].presence ||
      I18n.default_locale
  end

  # Get the translations for the frontend
  def frontend_translations(locale)
    I18n.t("frontend", locale: locale, default: {})
  end

  def set_filters
    @filters = {
        page: params[:page] || 1,
        per_page: params[:per_page] || 10
    }
  end

  # Builds a flat hash of capability_key => Boolean for the current user
  # within the current organization. A capability is considered held when
  # present in organization-wide caps OR in any property-scoped caps.
  # Returns an empty hash when no organization context is available.
  def resolve_current_capabilities
    return {} unless user_signed_in? && Current.organization

    profile = Authorization::GrantProfile.build(current_user, Current.organization)

    Authorization::Capabilities::ALL.each_with_object({}) do |cap, hash|
      has_org      = profile.organization_capabilities.include?(cap)
      has_property = profile.property_capabilities.values.any? { |caps| caps.include?(cap) }
      hash[cap] = has_org || has_property
    end
  end
end
