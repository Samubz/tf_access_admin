# frozen_string_literal: true

class Api::V1::BaseController < ActionController::API
  include Pundit::Authorization
  include ActsAsTenant::ControllerExtensions
  include Devise::Controllers::Helpers
  include RequestSubdomain

  set_current_tenant_through_filter
  before_action :set_current_organization

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  before_action :set_filters, if: -> { action_name == "index" }

  private

  def set_current_organization
    organization = resolve_organization
    return unauthorized_tenant if organization.blank?

    set_current_tenant(organization)
  end

  def set_filters
    @filters = {
        page: params[:page] || 1,
        per_page: params[:per_page] || 10
    }
  end

  def render_collection(collection, serializer:, **options)
    payload = ActiveModelSerializers::SerializableResource.new(
      collection,
      each_serializer: serializer,
      **options
    ).as_json
    render json: { data: payload }, status: :ok
  end

  def render_resource(resource, serializer:, **options)
    payload = ActiveModelSerializers::SerializableResource.new(
      resource,
      serializer: serializer,
      **options
    ).as_json
    render json: { data: payload }, status: :ok
  end

  def safe_limit(default: 20, max: 100)
    raw = params[:limit].to_i
    return default if raw <= 0

    [ raw, max ].min
  end

  def resolve_organization
    subdomain = api_subdomain_from_request
    return nil if subdomain.blank?

    get_organization_from_subdomain(subdomain)
  end

  def forbidden
    render json: { error: I18n.t("api.errors.forbidden") }, status: :forbidden
  end

  def not_found
    render json: { error: I18n.t("api.errors.not_found") }, status: :not_found
  end

  def unauthorized_tenant
    render json: { error: I18n.t("api.errors.unauthorized_tenant") }, status: :unauthorized
  end

  def unauthorized
    render json: { error: I18n.t("api.errors.unauthorized") }, status: :unauthorized
  end
end
