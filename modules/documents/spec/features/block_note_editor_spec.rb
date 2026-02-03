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

RSpec.describe "BlockNote editor rendering", :js, :selenium, with_settings: { real_time_text_collaboration_enabled: true } do
  let(:admin) { create(:admin) }
  let(:type) { create(:document_type, :experimental) }
  let(:document) { create(:document, type:) }
  let(:editor) { FormFields::Primerized::BlockNoteEditorInput.new }

  before do
    login_as(admin)

    # This is here while we don't have a setting defined for enabling/disabling collaboration
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Primer::OpenProject::Forms::BlockNoteEditor).to receive(:collaboration_enabled).and_return(false)
    # rubocop:enable RSpec/AnyInstance
  end

  it "renders the BlockNote editor in the users locale" do
    admin.update!(language: "de")
    visit document_path(document)

    expect(page).to have_test_selector("blocknote-document-description")
    expect(editor.content).not_to include("Überschrift")

    editor.open_command_dialog
    expect(editor.content).to include("Überschrift")
  end

  it "renders the BlockNote editor in english if the users locale is not available for BlockNote" do
    admin.update!(language: "af")
    visit document_path(document)

    expect(page).to have_test_selector("blocknote-document-description")
    expect(editor.content).not_to include("Heading")

    editor.open_command_dialog
    expect(editor.content).to include("Heading")
  end

  describe "with op-blocknote-extensions" do
    it "renders the BlockNote editor with custom menu entries for work package linking" do
      visit document_path(document)

      expect(page).to have_test_selector("blocknote-document-description")
      editor.fill_in("/openproject")
      expect(editor.content).to have_content("Link existing work package")
    end

    it "orders results of the work package search by updated at DESC" do
      create(:work_package, project: document.project, subject: "BBB test", updated_at: 4.hours.ago)
      create(:work_package, project: document.project, subject: "AAA test", updated_at: 2.hours.ago)
      create(:work_package, project: document.project, subject: "CCC test", updated_at: 3.hours.ago)

      visit document_path(document)
      expect(page).to have_test_selector("blocknote-document-description")

      editor.open_add_work_package_dialog
      editor.element.fill_in("Link existing work package", with: "test")
      expect(editor.element).to have_content("AAA test") # wait for dropdown to open
      expect(editor.element.text).to match(/AAA test.*CCC test.*BBB test/m)
    end

    it "is possible to add link work package blocks" do
      status = create(:status, name: "Open")
      type = create(:type, name: "Life Goals")
      work_package = create(:work_package,
                            project: document.project,
                            subject: "pet a tiger",
                            status:,
                            type:)

      visit document_path(document)
      expect(page).to have_test_selector("blocknote-document-description")

      editor.open_add_work_package_dialog
      editor.element.fill_in("Link existing work package", with: "tiger")
      editor.element.all("div", text: "pet a tiger").last.click

      expect(editor.element).to have_no_content("Link existing work package") # search dialog is closed
      expect(editor.element.text).to match(/LIFE GOALS\s#\d+\sOpen\spet a tiger/)

      # Capybara's have_link seems not to work in a shadow dom, so it's tested via the property
      expect(editor.element.find_link(text: "pet a tiger").native.property("href")).to end_with("/wp/#{work_package.id}")
    end
  end
end
