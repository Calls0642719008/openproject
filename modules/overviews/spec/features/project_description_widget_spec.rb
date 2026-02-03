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

require_relative "../support/pages/dashboard"

RSpec.describe "Project description widget", :js, with_flag: { new_project_overview: true } do
  let!(:type) { create(:type) }
  let!(:portfolio) { create(:portfolio, description: "") }
  let!(:open_status) { create(:default_status) }

  let(:permissions) do
    %i[manage_dashboards
       view_members
       view_work_packages
       add_work_packages
       save_queries
       manage_public_queries
       edit_project]
  end

  let(:user) do
    create(:user,
           member_with_permissions: { portfolio => permissions })
  end

  let(:dashboard_page) do
    Pages::Dashboard.new(portfolio)
  end

  context "as a user with permission" do
    before do
      login_as user

      dashboard_page.visit!
    end

    it "opens the dashboard, adds a project description widget, and edits it correctly" do
      expect(page).to have_current_path(dashboard_project_overview_path(portfolio))

      # Find the project description widget area
      description_widget_area = Components::Grids::GridArea.new("[data-test-selector*='grid-widget-project_description']")
      description_widget_area.expect_to_exist

      # Edit the project description within the widget
      within description_widget_area.area do
        # Find the editable description field
        description_field = TextEditorField.new(page, "description",
                                                selector: "op-editable-attribute-field[fieldname='description']")

        # Activate the field for editing
        description_field.activate!

        # Set a new description
        new_description = "This is a **test** project description with markdown formatting."
        description_field.set_value(new_description)

        # Save the changes
        description_field.save!
      end

      dashboard_page.expect_and_dismiss_toaster message: I18n.t("js.notice_successful_update")

      dashboard_page.visit!
      expect(page).to have_content("This is a test project description with markdown formatting.")

      portfolio.reload
      expect(portfolio.description).to include("This is a **test** project description")
    end
  end
end
