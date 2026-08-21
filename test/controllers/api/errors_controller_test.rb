# frozen_string_literal: true

require "test_helper"

class Api::ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "unmatched GET api path renders json 404" do
    get "/api/v1/does-not-exist"

    assert_response :not_found
    assert_equal I18n.t("api.errors.not_found"), response.parsed_body["error"]
  end

  test "unmatched non-GET api path renders json 404 instead of a CSRF 422" do
    delete "/api/v1/does-not-exist"

    assert_response :not_found
    assert_equal I18n.t("api.errors.not_found"), response.parsed_body["error"]
  end

  test "unmatched non-GET api path with a body renders json 404" do
    post "/api/v1/does-not-exist", params: { foo: "bar" }

    assert_response :not_found
    assert_equal I18n.t("api.errors.not_found"), response.parsed_body["error"]
  end
end
