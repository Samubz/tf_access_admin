# frozen_string_literal: true

require "test_helper"

class UserPasswordPolicyTest < ActiveSupport::TestCase
  def build_user(password)
    User.new(
      email: "pw-#{SecureRandom.hex(4)}@example.test",
      password: password,
      password_confirmation: password,
      name: "PW User",
      dni: SecureRandom.hex(4),
      language: Languages::ES
    )
  end

  test "accepts a password with lower, upper, digit, special and length >= 8" do
    assert build_user("Password1@").valid?
  end

  test "rejects when too short" do
    user = build_user("Pass1@")
    refute user.valid?
    assert_includes user.errors[:password], "admin.users.validations.password_complexity"
  end

  test "rejects without an uppercase letter" do
    refute build_user("password1@").valid?
  end

  test "rejects without a lowercase letter" do
    refute build_user("PASSWORD1@").valid?
  end

  test "rejects without a digit" do
    refute build_user("Password@@").valid?
  end

  test "rejects without a special character" do
    refute build_user("Password11").valid?
  end

  test "does not validate complexity when password is not being set" do
    user = create_confirmed_user(email: "existing-pw@example.test")
    user.name = "Renamed"
    assert user.valid?
  end
end
