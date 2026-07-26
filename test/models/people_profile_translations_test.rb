# frozen_string_literal: true

require "test_helper"

class PeopleProfileTranslationsTest < ActiveSupport::TestCase
  LOCALES = %i[es en pt].freeze

  PROFILE_KEYS = [
    "frontend.admin.people.profile.tabs.summary",
    "frontend.admin.people.profile.tabs.properties",
    "frontend.admin.people.profile.tabs.residences",
    "frontend.admin.people.profile.tabs.staff",
    "frontend.admin.people.profile.tabs.visits",
    "frontend.admin.people.profile.tabs.history",
    "frontend.admin.people.profile.contextual_roles.owner",
    "frontend.admin.people.profile.contextual_roles.resident",
    "frontend.admin.people.profile.staff.empty",
    "frontend.admin.people.profile.visits.empty",
    "frontend.admin.people.index.actions.view_profile"
  ].freeze

  test "profile navigation translations exist for es en and pt" do
    LOCALES.each do |locale|
      I18n.with_locale(locale) do
        PROFILE_KEYS.each do |key|
          translation = I18n.t(key)
          assert translation.present?, "missing translation for #{key} in #{locale}"
          refute translation.start_with?("translation missing"), "missing translation for #{key} in #{locale}"
        end
      end
    end
  end
end
