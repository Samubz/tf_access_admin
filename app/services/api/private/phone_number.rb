# frozen_string_literal: true

module Api
  module Private
    # Converts between Person#contact_phone (free string) and the mobile API
    # shape { countryCode, number }. A "+NN" prefix (optionally separated by
    # space/dash) is treated as country code; otherwise countryCode is "".
    module PhoneNumber
      SEPARATED = /\A(\+\d{1,3})[\s\-]+(.+)\z/
      COMPACT   = /\A(\+\d{2})(\d+)\z/

      module_function

      def split(raw)
        value = raw.to_s.strip
        return nil if value.blank?

        if (m = value.match(SEPARATED) || value.match(COMPACT))
          { countryCode: m[1], number: m[2] }
        else
          { countryCode: "", number: value }
        end
      end

      def join(country_code, number)
        number = number.to_s.strip
        return nil if number.blank?

        [ country_code.to_s.strip.presence, number ].compact.join(" ")
      end
    end
  end
end
