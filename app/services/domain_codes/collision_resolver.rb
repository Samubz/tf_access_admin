# frozen_string_literal: true

module DomainCodes
  # Appends a numeric suffix (`-2`, `-3`, …) to a base code until the caller's
  # scope reports it free (hierarchical-code-generation §Collision resolution).
  #
  # The +taken+ block receives a candidate string and returns truthy when it is
  # already used in the relevant uniqueness scope among non-deleted records.
  #
  #   CollisionResolver.call(base: "cdo-tor-torre-a") { |c| Section.exists?(code: c) }
  class CollisionResolver
    def self.call(base:, &taken)
      return base unless taken.call(base)

      counter = 2
      loop do
        candidate = "#{base}-#{counter}"
        return candidate unless taken.call(candidate)

        counter += 1
      end
    end
  end
end
