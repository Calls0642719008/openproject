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
require_relative "../shared_context"

RSpec.describe "Edit project custom fields on project overview page", :js do
  include_context "with seeded projects, members and project custom fields"

  let(:overview_page) { Pages::Projects::Show.new(project) }

  before do
    login_as member_with_project_attributes_edit_permissions
    overview_page.visit_page
  end

  it "opens a dialog showing the input for project custom field" do
    dialog = overview_page.open_edit_dialog_for_custom_field(boolean_project_custom_field)

    dialog.expect_open

    dialog.within_async_content(close_after_yield: true) do
      expect(page).to have_content(boolean_project_custom_field.name)
    end
  end

  it "renders the dialog body asynchronically" do
    dialog = Components::Projects::ProjectCustomFields::EditDialog.new(project, boolean_project_custom_field)

    expect(page).to have_no_css(dialog.async_content_container_css_selector, visible: :all)

    overview_page.open_edit_dialog_for_custom_field(boolean_project_custom_field)

    expect(page).to have_css(dialog.async_content_container_css_selector, visible: :visible)
  end

  it "can be closed via close icon or cancel button" do
    dialog = overview_page.open_edit_dialog_for_custom_field(boolean_project_custom_field)

    dialog.close_via_icon

    dialog.expect_closed

    dialog = overview_page.open_edit_dialog_for_custom_field(string_project_custom_field)

    dialog.close_via_button

    dialog.expect_closed
  end
end
