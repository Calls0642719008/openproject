# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe "External link capture", :js, :selenium do
  shared_let(:admin) { create(:admin) }

  let(:project) { create(:project, enabled_module_names: %w[wiki]) }
  let(:external_url) { "http://0.0.0.0:3001/" }
  let!(:wiki_page) do
    create(:wiki_page,
           wiki: project.wiki,
           author: admin,
           title: "Wiki Page with external link",
           text: %(A link to <a href="#{external_url}">OpenProject</a>.))
  end

  before do
    login_as(admin)
  end

  shared_examples "opens external link directly in a new window" do
    it "keeps the default external link behaviour" do
      visit project_wiki_path(project, wiki_page)

      link = page.find(%(a[href^="#{external_url}"]))
      new_window = window_opened_by { link.click }

      within_window new_window do
        expect(page.current_url).to start_with(external_url)
      end
    ensure
      begin
        new_window&.close
      rescue StandardError
        # Ignore errors from already-closed windows/tabs
      end
    end
  end

  context "when enterprise is available", with_ee: %i[capture_external_links] do
    it "allows enabling external link capture and shows a confirmation screen" do
      visit admin_settings_external_links_path

      scroll_to_element find_by_id("settings_capture_external_links")
      find_by_id("settings_capture_external_links").set(true)

      click_on "Save"
      expect(page).to have_text I18n.t(:notice_successful_update)

      RequestStore.clear!
      expect(Setting.capture_external_links?).to be(true)

      visit project_wiki_path(project, wiki_page)

      link = page.find('a[href^="/external_redirect?url="]')
      new_window = window_opened_by { link.click }

      within_window new_window do
        expect(page.current_url).to include("/external_redirect")
        expect(page).to have_text I18n.t("external_link_warning.title")
        expect(page).to have_text I18n.t("external_link_warning.warning_message")
        expect(page).to have_text I18n.t("external_link_warning.continue_message")

        expect(page).to have_link(I18n.t("external_link_warning.continue_button"), href: external_url)
      end
    ensure
      begin
        new_window&.close
      rescue StandardError
        # Ignore errors from already-closed windows/tabs
      end
    end
  end

  context "when no enterprise token is present" do
    it "does not allow enabling external link capture in administration" do
      visit admin_settings_external_links_path

      expect(page).to have_field("settings_capture_external_links", disabled: true)

      RequestStore.clear!
      expect(Setting.capture_external_links?).to be(false)
    end

    include_examples "opens external link directly in a new window"
  end
end
