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

RSpec.describe "MeetingParticipants requests",
               :skip_csrf,
               type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %i[meetings]) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_meetings create_meetings edit_meetings] }) }
  shared_let(:meeting) { create(:meeting, project:, author: user) }

  # Users with different permission levels
  shared_let(:user_with_meeting_permissions) { create(:user, member_with_permissions: { project => %i[view_meetings] }) }
  shared_let(:user_with_meeting_permissions2) { create(:user, member_with_permissions: { project => %i[view_meetings] }) }
  shared_let(:user_without_meeting_permissions) { create(:user, member_with_permissions: { project => %i[view_project] }) }
  shared_let(:user_not_in_project) { create(:user) }

  before do
    meeting.participants.delete_all
    login_as user
  end

  describe "POST /meetings/:meeting_id/participants" do
    let(:base_params) do
      {
        meeting_id: meeting.id,
        project_id: project.id,
        meeting_participant: {
          user_id: []
        }
      }
    end

    context "when inviting a single participant" do
      let(:params) { base_params.deep_merge(meeting_participant: { user_id: [user_with_meeting_permissions.id] }) }

      it "creates a single participant" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
        end.to change { meeting.participants.count }.by(1)

        expect(response).to have_http_status(:ok)

        participant = meeting.participants.reload.last
        expect(participant.user).to eq(user_with_meeting_permissions)
        expect(participant.invited).to be true
        expect(participant.attended).to be false
      end

      it "sends notification email" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
          perform_enqueued_jobs
        end.to change { ActionMailer::Base.deliveries.size }.by(1)
      end
    end

    context "when inviting multiple participants" do
      let(:params) do
        base_params.deep_merge(
          meeting_participant: {
            user_id: [user_with_meeting_permissions.id, user_with_meeting_permissions.id]
          }
        )
      end

      it "creates multiple participants" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
        end.to change { meeting.participants.count }.by(2)

        expect(response).to have_http_status(:ok)

        participants = meeting.participants.reload.last(2)
        expect(participants.map(&:user)).to all(eq(user_with_meeting_permissions))
        expect(participants.map(&:attended)).to all(be false)
      end
    end

    context "when inviting participants with different permission levels" do
      let(:params) do
        base_params.deep_merge(
          meeting_participant: {
            user_id: [user_with_meeting_permissions.id, user_without_meeting_permissions.id]
          }
        )
      end

      it "creates participants for users with meeting permissions" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
        end.to change { meeting.participants.count }.by(1)

        expect(response).to have_http_status(:ok)

        participant = meeting.participants.reload.last
        expect(participant.user).to eq(user_with_meeting_permissions)
      end

      it "adds errors for users without meeting permissions" do
        post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.body).to include "User #{user_without_meeting_permissions.name} is not a valid participant."

        meeting.participants.reload
        expect(meeting.participants.count).to eq(1)
        expect(meeting.participants.first.user).to eq(user_with_meeting_permissions)
      end
    end

    context "when inviting users not in the project" do
      let(:params) do
        base_params.deep_merge(
          meeting_participant: {
            user_id: [user_not_in_project.id]
          }
        )
      end

      it "does not create participants for users not in project" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
        end.not_to change { meeting.participants.count }

        expect(response).to have_http_status(:ok)
      end

      it "adds appropriate errors" do
        post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream

        expect(response.body).to include "User #{user_not_in_project.name} is not a valid participant."

        meeting.participants.reload
        expect(meeting.participants.count).to eq(0)
      end
    end

    context "when providing empty user_ids" do
      let(:params) { base_params }

      it "does not create any participants" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
        end.not_to change { meeting.participants.count }

        expect(response).to have_http_status(:ok)
      end
    end

    context "when providing nil user_ids" do
      let(:params) { base_params.deep_merge(meeting_participant: { user_id: nil }) }

      it "handles nil gracefully" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
        end.not_to change { meeting.participants.count }

        expect(response).to have_http_status(:ok)
      end
    end

    context "when providing invalid user_ids" do
      let(:params) do
        base_params.deep_merge(
          meeting_participant: {
            user_id: [999999, user_with_meeting_permissions.id]
          }
        )
      end

      it "creates participants for valid users only" do
        expect do
          post project_meeting_participants_path(project, meeting), params: params, as: :turbo_stream
        end.to change { meeting.participants.count }.by(1)

        expect(response).to have_http_status(:ok)

        meeting.participants.reload
        expect(meeting.participants.count).to eq(1)
        expect(meeting.participants.first.user).to eq(user_with_meeting_permissions)
      end
    end
  end

  describe "POST /meetings/:meeting_id/participants/mark_all_attended" do
    let!(:participant1) { create(:meeting_participant, meeting:, user: user_with_meeting_permissions, attended: false) }
    let!(:participant2) { create(:meeting_participant, meeting:, user: user_with_meeting_permissions2, attended: false) }

    it "marks all participants as attended" do
      post mark_all_attended_project_meeting_participants_path(project, meeting), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(participant1.reload.attended).to be true
      expect(participant2.reload.attended).to be true
    end
  end

  describe "POST /meetings/:meeting_id/participants/:id/toggle_attendance" do
    let!(:participant) { create(:meeting_participant, meeting:, user: user_with_meeting_permissions, attended: false) }

    it "toggles attendance status" do
      expect do
        post toggle_attendance_project_meeting_participant_path(project, meeting, participant), as: :turbo_stream
      end.to change { participant.reload.attended }.from(false).to(true)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /meetings/:meeting_id/participants/:id" do
    let!(:participant) { create(:meeting_participant, meeting:, user: user_with_meeting_permissions) }

    it "removes the participant" do
      expect do
        delete project_meeting_participant_path(project, meeting, participant), as: :turbo_stream
      end.to change { meeting.participants.count }.by(-1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /meetings/:meeting_id/participants/manage_participants_dialog" do
    it "responds with the manage participants dialog" do
      get manage_participants_dialog_project_meeting_participants_path(project, meeting), as: :turbo_stream

      expect(response).to have_http_status(:ok)
    end
  end
end
