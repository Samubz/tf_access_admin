# frozen_string_literal: true

# Extended visitor profile associated with the canonical identity in +people+.
#
# +Person+ is the only identity store per organization. +VisitorProfile+ is not a
# parallel identity table: it holds visitor-specific attributes (security notes,
# external name, company, transitional contact fields) while the canonical identity
# lives on +Person+ via +person_id+.
#
# Integration contract:
# - New visitor flows MUST resolve or create a +Person+ first (e.g. via
#   +People::FindExisting+) and link the profile through +person_id+.
# - +person_id+ may be optional on legacy rows during migration; operational flows
#   should treat an unlinked profile as transitional, not as a separate identity.
# - The unified person profile and +People::ContextualRoles+ derive the +visitor+
#   badge from linked +visitor_profiles+, not from this table alone.
#
# Do not remove or replace +visitor_profiles+ in favor of a separate visitors
# identity table.
#
# == Schema Information
#
# Table name: visitor_profiles
#
#  id                         :uuid             not null, primary key
#  company_name               :string
#  deleted_at                 :datetime
#  document_number_ciphertext :text
#  document_number_digest     :string
#  document_type              :string
#  email_ciphertext           :text
#  external_name              :string
#  metadata                   :jsonb            not null
#  phone_ciphertext           :text
#  security_notes             :text
#  status                     :string           default("active"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  organization_id            :uuid             not null
#  person_id                  :uuid
#
# Indexes
#
#  index_visitor_profiles_on_deleted_at                           (deleted_at)
#  index_visitor_profiles_on_metadata                             (metadata) USING gin
#  index_visitor_profiles_on_organization_id                      (organization_id)
#  index_visitor_profiles_on_organization_id_and_person_id        (organization_id,person_id)
#  index_visitor_profiles_on_organization_id_and_status           (organization_id,status)
#  index_visitor_profiles_on_person_id                            (person_id)
#  index_visitor_profiles_unique_doc_digest_per_org_when_present  (organization_id,document_number_digest) UNIQUE WHERE ((deleted_at IS NULL) AND (document_number_digest IS NOT NULL))
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (person_id => people.id)
#
class VisitorProfile < ApplicationRecord
  include TenantScopedAssociations

  acts_as_tenant :organization
  acts_as_paranoid

  belongs_to :organization
  belongs_to :person, optional: true

  validates_same_tenant :person
end
