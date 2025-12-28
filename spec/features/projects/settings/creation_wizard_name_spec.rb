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

RSpec.describe "Project creation wizard name settings", :js,
               with_flag: { project_initiation_active: true } do
  shared_let(:admin) { create(:admin) }

  let!(:project) { create(:project, project_creation_wizard_enabled: true) }
  let(:name_page) { Pages::Projects::Settings::CreationWizard.new(project, tab: "name") }

  current_user { admin }

  describe "configuring name settings" do
    it "allows admin to configure artifact name" do
      name_page.visit!

      expect(page).to have_select("Artifact name")
      expect(page).to have_text("Choose the name for this artifact that your project management framework recommends.")

      select "Project initiation request", from: "Artifact name"
      click_button "Save"

      expect_and_dismiss_flash(message: "Successful update.")

      project.reload
      expect(project.project_creation_wizard_artifact_name).to eq("project_initiation_request")
    end
  end
end
