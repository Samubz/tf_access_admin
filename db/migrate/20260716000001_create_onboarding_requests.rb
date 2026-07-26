# frozen_string_literal: true

class CreateOnboardingRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_requests, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :residential_property, null: true, foreign_key: true, type: :uuid
      t.references :unit, null: true, foreign_key: true, type: :uuid
      t.references :person, null: true, foreign_key: true, type: :uuid
      t.references :user, null: true, foreign_key: true, type: :uuid
      t.references :requested_by_person, null: true, type: :uuid,
                   foreign_key: { to_table: :people }

      t.string :requested_relationship, null: false
      t.jsonb :requested_roles, null: false, default: []
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.string :token_digest
      t.string :conflict_reason
      t.jsonb :metadata, null: false, default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :onboarding_requests, :deleted_at
    add_index :onboarding_requests, :status
    add_index :onboarding_requests, :token_digest,
              unique: true,
              where: "token_digest IS NOT NULL",
              name: "idx_onboarding_requests_unique_token_digest"

    # Best-effort DB idempotency for pending requests. NOTE: Postgres treats a
    # NULL person_id as distinct, so full pending-idempotency (email-only
    # invites, user_id-based) is enforced in the service layer (spec §7).
    add_index :onboarding_requests,
              %i[organization_id person_id requested_relationship residential_property_id unit_id],
              unique: true,
              where: "status = 'pending' AND deleted_at IS NULL",
              name: "idx_onboarding_requests_unique_pending_scope"
  end
end
