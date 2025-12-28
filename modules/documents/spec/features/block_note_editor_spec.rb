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

RSpec.describe "BlockNote editor rendering", :js do
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

  it "renders the BlockNote editor with custom menu entries for work package linking" do
    pending("handling tests with shadow dom")
    visit document_path(document)

    expect(page).to have_test_selector("blocknote-document-description")
    editor.fill_in_with_content("/openproject")
    expect(page).to have_content("Link to existing work package")
  end
end
