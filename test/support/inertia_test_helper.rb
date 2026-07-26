# frozen_string_literal: true

module InertiaTestHelper
  def inertia_headers
    {
      "X-Inertia" => "true",
      "X-Inertia-Version" => ViteRuby.digest,
      "X-Requested-With" => "XMLHttpRequest"
    }
  end

  def inertia_get(path)
    get path, headers: inertia_headers
  end

  def inertia_props
    JSON.parse(response.body)["props"]
  end

  def inertia_component
    JSON.parse(response.body)["component"]
  end

  def inertia_field_error(model_class, attribute, message)
    label = model_class.human_attribute_name(attribute)
    { attribute => [ "#{label} #{message}" ] }
  end

  def expected_inertia_errors(record)
    record.errors.to_hash(true).transform_values { |messages| Array(messages) }
  end
end
