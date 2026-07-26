# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  deactivated_at         :datetime
#  deleted_at             :datetime
#  dni                    :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  global_status          :string           default("active"), not null
#  language               :string
#  last_active_at         :datetime
#  metadata               :jsonb            not null
#  name                   :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  suspended_at           :datetime
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_deactivated_at        (deactivated_at)
#  index_users_on_deleted_at            (deleted_at)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_global_status         (global_status)
#  index_users_on_metadata              (metadata) USING gin
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_suspended_at          (suspended_at)
#
class User < ApplicationRecord
  acts_as_paranoid
  include Users::Features

  has_many :people, dependent: :destroy
  has_many :organization_memberships, through: :people
  has_many :organizations, through: :people
  has_many :created_visits, class_name: "Visit", foreign_key: :created_by_id, dependent: :nullify
  has_many :authorized_visits, class_name: "Visit", foreign_key: :authorized_by_id, dependent: :nullify
  has_many :checked_in_visits, class_name: "Visit", foreign_key: :checked_in_by_id, dependent: :nullify
  has_many :checked_out_visits, class_name: "Visit", foreign_key: :checked_out_by_id, dependent: :nullify
  has_one :device_token, dependent: :destroy
  has_one_attached :avatar

  # Identity provisioning is explicit (Accounts::ProvisionTenantIdentity), invoked
  # by admin account creation. Creating a User no longer auto-creates a Person:
  # a bare User (e.g. self-registration) is a valid, org-less account.

  # Server-side password policy (mirrors the frontend Zod rule, plus a digit):
  # min 8 chars with at least one lowercase, uppercase, digit and special char
  # from the shared set. Applies to every path that sets a password (invitation
  # acceptance, admin creation, password change).
  PASSWORD_COMPLEXITY = /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[$%@.\-_]).{8,}\z/

  validates :name, presence: true
  validates :dni, presence: true
  validates :language, presence: true, inclusion: { in: Languages::ALL }
  validates :email, uniqueness: { message: "admin.users.validations.email_taken" }
  validate :password_meets_complexity

  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :confirmable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  def self.find_for_authentication(conditions)
    conditions = conditions&.dup || {}
    organization_id = conditions.delete(:organization_id)
    email = conditions[:email]
    user = find_by(email: email)
    return nil unless user

    return user if organization_id.blank?

    org = Organization.find_by(id: organization_id)
    return nil unless org

    return user if user.super_admin?

    user.member_of_tenant?(org) ? user : nil
  end

  def jwt_payload
    org = Current.organization || ActsAsTenant.current_tenant
    { "organization_id" => org&.id.to_s }
  end

  def person_for(organization)
    return nil if organization.blank?

    ActsAsTenant.without_tenant { people.find_by(organization_id: organization.id) }
  end

  def member_of_tenant?(organization)
    return false if organization.blank?

    person = person_for(organization)
    return false unless person

    m = person.organization_membership
    m.present? && m.status.in?(%w[active invited])
  end

  def role
    person = person_for(ActsAsTenant.current_tenant)
    return nil unless person

    pr = person.roles
    return nil if pr.blank?

    pr.min_by { |r| AvailableRoles.priority_index(r.name, :global) }.name
  end

  def tenant_role
    person = person_for(ActsAsTenant.current_tenant)
    return nil unless person

    pr = person.roles
    return nil if pr.blank?

    pr.min_by { |r| AvailableRoles.priority_index(r.name, :tenant) }.name
  end

  def super_admin?
    ActsAsTenant.without_tenant do
      people.any? { |p| p.has_role?(AvailableRoles::SUPER_ADMIN) }
    end
  end

  def client_global?
    ActsAsTenant.without_tenant do
      people.any? { |p| p.has_role?(AvailableRoles::CLIENT) }
    end
  end

  def tenant_admin?(tenant = nil)
    tenant ||= ActsAsTenant.current_tenant
    return false unless tenant

    person = person_for(tenant)
    return false unless person

    person.has_role?(AvailableRoles::TENANT_ADMIN, tenant)
  end

  def set_tenant_role(role_name)
    org = ActsAsTenant.current_tenant
    person = person_for(org)
    raise ActiveRecord::RecordNotFound, "Missing Person for tenant" unless person

    person.set_tenant_role(role_name)
  end

  def avatar_path
    BlobUrls.url_for(avatar)
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[name email dni]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[people]
  end

  private

  def password_meets_complexity
    return if password.blank?
    return if password.match?(PASSWORD_COMPLEXITY)

    errors.add(:password, "admin.users.validations.password_complexity")
  end
end
