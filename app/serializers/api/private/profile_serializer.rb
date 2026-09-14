# frozen_string_literal: true

# Profile payload for GET/PATCH /api/v1/private/me.
# Expects instance option +organization+ (current tenant).
class Api::Private::ProfileSerializer < ActiveModel::Serializer
  attributes :email, :name, :dni, :phone, :gender, :role, :organizations
  attribute :date_of_birth, key: :dateOfBirth
  attribute :avatar_url, key: :avatarUrl

  def phone
    Api::Private::PhoneNumber.split(person&.contact_phone)
  end

  def date_of_birth
    person&.birthdate&.iso8601
  end

  # Gender is not modelled; always null.
  def gender
    nil
  end

  def avatar_url
    object.avatar_path
  end

  def role
    Api::RoleResolver.call(object, organization)
  end

  # Organizations where the user has an active/invited membership or an active
  # unit relationship. Crosses tenants, hence resolved without tenant scope.
  def organizations
    ActsAsTenant.without_tenant do
      object.people.includes(:organization).filter_map do |person|
        org = person.organization
        units_count = Unit.with_active_relationship_for(person, org).distinct.count
        next unless units_count.positive? || object.member_of_tenant?(org)

        { id: org.id, name: org.name, logo: org.logo_path, units_count: units_count }
      end
    end
  end

  private

  def organization
    @instance_options[:organization]
  end

  def person
    @person ||= object.person_for(organization)
  end
end
