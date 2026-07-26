# frozen_string_literal: true

# Shared case- and accent-insensitive matching for name search endpoints
# (improve-admin-visit-form-inputs, design.md Decision 7). Requires the
# Postgres `unaccent` extension (see db/migrate/20260706120000).
module AccentInsensitiveMatch
  def self.where_clause(*columns)
    columns.map { |column| "unaccent(#{column}) ILIKE unaccent(:term)" }.join(" OR ")
  end

  def self.term(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s.strip)}%"
  end
end
