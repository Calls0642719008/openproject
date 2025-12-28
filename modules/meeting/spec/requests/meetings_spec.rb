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

RSpec.describe "Meeting requests",
               :skip_csrf,
               type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %i[meetings]) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_meetings create_meetings edit_meetings] }) }
  shared_let(:meeting) { create(:meeting, project:, author: user) }

  before do
    meeting.participants.delete_all
    login_as user
  end

  describe "Meetings index" do
    context "when sorting by meeting type" do
      it "does not raise an error (Regression #55839)" do
        get meetings_path(sort: "type", filters: '[{"time":{"operator":"=","values":["future"]}}]')
        expect(response).to have_http_status(:ok)
        expect(response.body).to have_text(meeting.title)
      end
    end
  end

  describe "show" do
    context "when meeting belongs to another project the user has no access to" do
      let(:other_project) { create(:project, enabled_module_names: %i[meetings]) }
      let(:other_meeting) { create(:meeting, project: other_project) }

      it "returns 404" do
        get meeting_path(other_meeting)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "copy" do
    let(:base_params) do
      {
        project_id: project.id,
        meeting: {
          title: "Copied meeting",
          type: "Meeting",
          copied_from_meeting_id: meeting.id
        }
      }
    end
    let(:params) { {} }

    context "when copying agenda items" do
      let!(:agenda_item) { create(:meeting_agenda_item, meeting:, notes: "**foo**") }
      let(:params) { { copy_agenda: "1" } }

      it "copies the agenda items" do
        post meetings_path(project),
             params: base_params.merge(params)

        meeting = Meeting.find_by(title: "Copied meeting")

        expect(response).to be_redirect

        expect(meeting).to be_present
        expect(meeting.agenda_items.count).to eq(1)
        expect(meeting.agenda_items.first.notes).to eq("**foo**")
      end
    end

    describe "does not send notifications" do
      before do
        post meetings_path(project),
             params: base_params

        Meeting.find_by(title: "Copied meeting")
        perform_enqueued_jobs
      end

      it do
        expect(ActionMailer::Base.deliveries.size).to eq 0
      end
    end

    context "when copying without additional params" do
      it "copies the meeting, but not the agenda" do
        post meetings_path(project),
             params: base_params.merge(params)

        meeting = Meeting.find_by(title: "Copied meeting")

        expect(response).to be_redirect

        expect(meeting).to be_present
        expect(meeting.agenda_items).to be_empty
      end
    end

    context "when meeting is not visible" do
      let(:other_project) { create(:project) }
      let(:meeting) { create(:meeting, project: other_project) }

      it "renders a 404" do
        post meetings_path(project),
             params: base_params.merge(params)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
