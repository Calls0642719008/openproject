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

require "#{File.dirname(__FILE__)}/../spec_helper"

RSpec.describe DocumentsController do
  render_views

  let(:admin) { create(:admin) }
  let(:project) { create(:project, name: "Test Project") }
  let(:user) { create(:user) }
  let(:role) { create(:project_role, permissions: [:view_documents]) }

  let(:document_type) do
    create(:document_type, name: "Default Type")
  end

  let!(:document) do
    create(:document, title: "Sample Document", project:, type: document_type)
  end

  current_user { admin }

  describe "index" do
    before do
      get :index, params: { project_id: project.identifier }
    end

    it "renders the index-template successfully" do
      expect(response).to be_successful
      expect(response).to render_template("index")
    end
  end

  describe "new" do
    before do
      get :new, params: { project_id: project.id }
    end

    it "returns render the new page successfully" do
      expect(response).to be_successful
      expect(response).to render_template("new")
    end
  end

  describe "edit" do
    context "with a classic document" do
      before do
        document.update(kind: :classic)
        get :edit, params: { id: document.id }
      end

      it "renders the edit-template successfully" do
        expect(response).to be_successful
        expect(response).to render_template("edit")
      end
    end

    context "with a collaborative document" do
      before do
        document.update(kind: :collaborative)
        get :edit, params: { id: document.id }
      end

      it "responds with a bad request" do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "create" do
    let(:document_attributes) do
      attributes_for(:document,
                     title: "New Document",
                     project_id: project.id,
                     type_id: document_type.id,
                     kind: "classic")
    end

    before do
      ActionMailer::Base.deliveries.clear
    end

    it "creates a new document with valid arguments" do
      expect do
        post :create,
             params: {
               project_id: project.identifier,
               document: document_attributes
             }
      end.to change(Document, :count).by(1)
      expect(Document.last.attributes).to include(document_attributes.stringify_keys)
    end

    it "does trigger a workflow job for the document" do
      expect(Notifications::WorkflowJob)
        .to have_been_enqueued
              .with(:create_notifications, document.journals.last, true)
    end

    describe "with attachments" do
      let(:uncontainered) { create(:attachment, container: nil, author: admin) }

      before do
        notify_project = project
        create(:member, project: notify_project, user:, roles: [role])

        post :create,
             params: {
               project_id: notify_project.identifier,
               document: attributes_for(:document,
                                        title: "New Document",
                                        project_id: notify_project.id,
                                        type_id: document_type.id,
                                        kind: "classic"),
               attachments: { "1" => { id: uncontainered.id } }
             }
      end

      it "adds an attachment" do
        document = Document.last

        expect(document.attachments.count).to be 1
        attachment = document.attachments.first
        expect(uncontainered.reload).to eql attachment
      end

      it "redirects to the documents-page" do
        expect(response).to redirect_to project_documents_path(project.identifier)
      end
    end
  end

  describe "show" do
    before do
      document.update(kind: :classic)
      get :show, params: { id: document.id }
    end

    it "shows the attachment" do
      expect(response).to be_successful
      expect(response).to render_template("show")
    end
  end

  describe "destroy" do
    before do
      document
    end

    it "deletes the document and redirects with 303 See Other" do
      expect do
        delete :destroy, params: { id: document.id }
      end.to change(Document, :count).by -1

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to project_documents_path(project)
      expect { Document.find(document.id) }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  describe "generate_oauth_token",
           with_config: { collaborative_editing_hocuspocus_secret: "secret1234" } do
    let(:manage_role) { create(:project_role, permissions: %i[view_documents manage_documents]) }
    let(:view_only_role) { create(:project_role, permissions: [:view_documents]) }
    let(:user_with_manage) { create(:user) }
    let(:user_without_manage) { create(:user) }

    before do
      create(:member, project:, user: user_with_manage, roles: [manage_role])
      create(:member, project:, user: user_without_manage, roles: [view_only_role])

      document.update(kind: :collaborative)
    end

    context "when user has manage_documents permission" do
      current_user { user_with_manage }

      it "generates an OAuth token for show action" do
        get :show, params: { id: document.id }
        expect(assigns(:oauth_token)).to be_present
      end
    end

    context "when user does not have manage_documents permission" do
      current_user { user_without_manage }

      it "generates an OAuth token for show action" do
        get :show, params: { id: document.id }
        expect(assigns(:oauth_token)).to be_present
      end
    end
  end

  def file_attachment
    test_document = "#{OpenProject::Documents::Engine.root}/spec/assets/attachments/testfile.txt"
    Rack::Test::UploadedFile.new(test_document, "text/plain")
  end
end
