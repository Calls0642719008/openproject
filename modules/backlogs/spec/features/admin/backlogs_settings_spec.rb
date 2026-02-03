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

require "rails_helper"

RSpec.describe "Backlogs Admin Settings", :js do
  let!(:type1) { create(:type, name: "Story", position: 1) }
  let!(:type2) { create(:type_feature,        position: 2) }
  let!(:type3) { create(:type_task,           position: 3) }
  let!(:type4) { create(:type_milestone,      position: 4) }

  let(:current_user) { create(:admin) }

  before do
    login_as current_user

    visit admin_backlogs_settings_path
  end

  scenario "updating story types" do
    expect(page).to have_heading "Backlogs"

    click_on accessible_description: "Story types"

    within_dialog "Select types" do
      within(:role, :listbox, accessible_name: "Select types options") do
        page.find(:role, :option, accessible_name: "FEATURE").click
        page.find(:role, :option, accessible_name: "STORY").click
      end

      click_on "Apply"
    end

    expect(page).to have_button accessible_description: "Story types", text: "Selected types: Story, Feature"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    expect(page).to have_button accessible_description: "Story types", text: "Selected types: Story, Feature"
  end

  scenario "filtering story types" do
    expect(page).to have_heading "Backlogs"

    click_on accessible_description: "Story types"

    within_dialog "Select types" do
      within(:role, :listbox, accessible_name: "Select types options") do
        expect(page).to have_selector :role, :option, count: 4, visible: :visible
      end
      fill_in "Filter", with: "f"

      within(:role, :listbox, accessible_name: "Select types options") do
        expect(page).to have_selector :role, :option, count: 1, visible: :visible
      end

      click_on "Apply"
    end
  end

  scenario "updating task type" do
    expect(page).to have_heading "Backlogs"

    click_on accessible_description: "Task type"

    within_dialog "Select a type" do
      within(:role, :listbox, accessible_name: "Select a type options") do
        page.find(:role, :option, accessible_name: "TASK").click
      end
    end

    expect(page).to have_button accessible_description: "Task type", text: "Selected type: Task"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    expect(page).to have_button accessible_description: "Task type", text: "Selected type: Task"
  end

  scenario "ensuring the same type is not selected as story and task type" do
    expect(page).to have_heading "Backlogs"

    click_on accessible_description: "Story types"

    within_dialog "Select types" do
      within(:role, :listbox, accessible_name: "Select types options") do
        expect(page).to have_selector(:role, :option, accessible_name: "STORY")

        page.find(:role, :option, accessible_name: "FEATURE").click
      end

      click_on "Apply"
    end

    expect(page).to have_button accessible_description: "Story types", text: "Selected types: Feature"

    click_on accessible_description: "Task type"

    within_dialog "Select a type" do
      within(:role, :listbox, accessible_name: "Select a type options") do
        expect(page).to have_selector(:role, :option, accessible_name: "FEATURE", aria: { disabled: true })

        page.find(:role, :option, accessible_name: "STORY").click
      end
    end

    expect(page).to have_button accessible_description: "Task type", text: "Selected type: Story"

    click_on accessible_description: "Story types"

    within_dialog "Select types" do
      within(:role, :listbox, accessible_name: "Select types options") do
        expect(page).to have_selector(:role, :option, accessible_name: "STORY", aria: { disabled: true })
      end

      click_on "Apply"
    end
  end

  scenario "updating points burn direction" do
    expect(page).to have_heading "Backlogs"

    choose "Down", fieldset: "Points burn up/down"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    expect(page).to have_checked_field "Down", fieldset: "Points burn up/down"
  end

  scenario "updating template for wiki page" do
    expect(page).to have_heading "Backlogs"

    fill_in "Template for sprint wiki page", with: "my_sprint_wiki_page"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    expect(page).to have_field "Template for sprint wiki page", with: "my_sprint_wiki_page"
  end
end
