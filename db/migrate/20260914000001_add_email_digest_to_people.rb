# frozen_string_literal: true

# D3 — blind index (SHA-256 of the normalized email) so visitor Persons can be
# resolved by email within an organization, mirroring document_number_digest.
class AddEmailDigestToPeople < ActiveRecord::Migration[8.1]
  class MigrationPerson < ApplicationRecord
    self.table_name = "people"
  end

  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    add_column :people, :email_digest, :string

    MigrationPerson.reset_column_information
    MigrationPerson.find_each(batch_size: 500) do |person|
      email = person.metadata.to_h["import_email"].presence
      email ||= MigrationUser.where(id: person.user_id).pick(:email) if person.user_id.present?
      normalized = email.to_s.downcase.strip
      next if normalized.blank?

      person.update_columns(email_digest: Digest::SHA256.hexdigest(normalized))
    end

    add_index :people, %i[organization_id email_digest],
              unique: true,
              where: "email_digest IS NOT NULL AND deleted_at IS NULL",
              name: "idx_people_unique_email_per_org_when_present"
  end

  def down
    remove_index :people, name: "idx_people_unique_email_per_org_when_present"
    remove_column :people, :email_digest
  end
end
