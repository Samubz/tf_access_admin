# frozen_string_literal: true

require "test_helper"

class JwtDenylistTest < ActiveSupport::TestCase
  setup do
    @user = create_confirmed_user(email: "jwt-denylist@example.com")
  end

  test "jwt_revoked? is true when the jti is explicitly denylisted" do
    payload = { "jti" => "some-jti", "iat" => Time.current.to_i }
    JwtDenylist.create!(jti: "some-jti", exp: 1.hour.from_now)

    assert JwtDenylist.jwt_revoked?(payload, @user)
  end

  test "jwt_revoked? is false when password_changed_at is nil, regardless of token age" do
    @user.update_column(:password_changed_at, nil)
    payload = { "jti" => "unrelated-jti", "iat" => 10.years.ago.to_i }

    assert_not JwtDenylist.jwt_revoked?(payload, @user)
  end

  test "jwt_revoked? is true when the token was issued before the last password change" do
    @user.update_column(:password_changed_at, Time.current)
    payload = { "jti" => "unrelated-jti", "iat" => 1.minute.ago.to_i }

    assert JwtDenylist.jwt_revoked?(payload, @user)
  end

  test "jwt_revoked? is false when the token was issued at or after the last password change" do
    changed_at = Time.current
    @user.update_column(:password_changed_at, changed_at)
    payload = { "jti" => "unrelated-jti", "iat" => changed_at.to_i }

    assert_not JwtDenylist.jwt_revoked?(payload, @user)
  end
end
