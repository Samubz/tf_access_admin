module Users::Features
  extend ActiveSupport::Concern

  BASIC_FEATURES = [
    :home,
    :users,
    :people,
    :residential_properties
    # :settings
  ].freeze

  def features
    features_keys.map do |key|
      {
        key: key,
        url: features_url[key]
      }
    end
  end

  private

  # Los *_path de Rails solo existen en controllers/views; en modelos usar url_helpers.
  def route_helpers
    Rails.application.routes.url_helpers
  end

  def features_keys
    keys = BASIC_FEATURES.dup
    org = ActsAsTenant.current_tenant
    return keys unless org

    keys << :organizations if Flipper.enabled?(:organizations, org) && super_admin?
    keys << :organization_settings if Flipper.enabled?(:organizations, org) && tenant_admin?(org)
    keys
  end

  def features_url
    h = route_helpers
    {
      home: h.admin_home_index_path,
      users: h.admin_users_path,
      people: h.admin_people_path,
      residential_properties: h.admin_residential_properties_path,
      # No hay ruta admin/organizations aún; mismo destino que home hasta que exista.
      organizations: h.admin_organizations_path,
      organization_settings: h.admin_organization_path(ActsAsTenant.current_tenant)
      # settings: h.edit_admin_profile_path(self)
    }
  end
end
