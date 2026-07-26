# frozen_string_literal: true

module DomainCodes
  # Canonical slugger for derived codes (hierarchical-code-generation §Slug).
  #
  # Transliterates accents to ASCII, downcases, converts any run of non
  # `[a-z0-9]` characters to a single hyphen, and caps the segment length. Pure:
  # no database access. Never parses numeric/letter suffixes from the input.
  #
  #   Slug.call("Torre Á")   # => "torre-a"
  #   Slug.call("Área 4")    # => "area-4"
  #   Slug.call("Torre 123") # => "torre-123"
  class Slug
    MAX_SEGMENT_LENGTH = 32

    def self.call(value, max_length: MAX_SEGMENT_LENGTH)
      slug = value.to_s.parameterize
      return slug if slug.length <= max_length

      slug[0, max_length].sub(/-+\z/, "")
    end
  end
end
