# frozen_string_literal: true

module UserTestHelper
  def create_confirmed_user(email:, name: "Test User")
    User.create!(
      email: email,
      password: "Password1@",
      password_confirmation: "Password1@",
      name: name,
      dni: SecureRandom.hex(4),
      language: Languages::ES,
      confirmed_at: Time.current
    )
  end

  def create_user_for_organization(organization:, email:, role:, name: "Test User")
    ActsAsTenant.with_tenant(organization) do
      user = create_confirmed_user(email: email, name: name)
      person = Accounts::ProvisionTenantIdentity.call(user: user, organization: organization)

      case role
      when AvailableRoles::SUPER_ADMIN
        person.add_role(AvailableRoles::SUPER_ADMIN)
      when AvailableRoles::CLIENT
        nil
      else
        user.set_tenant_role(role)
      end

      user
    end
  end
end
