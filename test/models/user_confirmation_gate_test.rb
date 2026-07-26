# frozen_string_literal: true

require "test_helper"

class UserConfirmationGateTest < ActiveSupport::TestCase
  def build_user(confirmed:)
    User.create!(
      email: "gate-#{SecureRandom.hex(4)}@example.test",
      password: "Password1@",
      password_confirmation: "Password1@",
      name: "Gate User",
      dni: SecureRandom.hex(4),
      language: Languages::ES,
      confirmed_at: confirmed ? Time.current : nil
    )
  end

  test "unconfirmed user cannot authenticate (no grace period)" do
    user = build_user(confirmed: false)
    refute user.active_for_authentication?
  end

  test "confirmed user can authenticate" do
    user = build_user(confirmed: true)
    assert user.active_for_authentication?
  end
end
