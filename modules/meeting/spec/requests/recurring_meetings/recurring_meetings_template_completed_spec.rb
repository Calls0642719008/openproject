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
require_relative "../../support/pages/recurring_meeting/show"

RSpec.describe "Recurring meetings complete template",
               :skip_csrf,
               type: :rails_request,
               with_settings: { date_format: "%Y-%m-%d" } do
  include Redmine::I18n

  shared_let(:project) { create(:project, enabled_module_names: %i[meetings]) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_meetings create_meetings edit_meetings] }) }
  shared_let(:recurring_meeting) do
    create :recurring_meeting,
           project:,
           author: user,
           start_time: DateTime.parse("2024-12-05T10:00:00Z"),
           frequency: "daily"
  end

  let(:current_user) { user }
  let(:show_page) { Pages::RecurringMeeting::Show.new(recurring_meeting).with_capybara_page(page) }
  let(:request) do
    post template_completed_project_recurring_meeting_path(project, recurring_meeting), as: :turbo_stream,
                                                                                        params: { meeting: { notify: "1" } }
  end

  subject do
    Timecop.freeze("2024-12-04T10:00:00Z".to_datetime) { request }
  end

  before do
    login_as(current_user)
  end

  context "when first occurrence is not existing" do
    it "instantiates the first occurrence from template and schedules the init job" do
      expect { subject }.to change(recurring_meeting.scheduled_meetings, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="redirect_to"')
      expect(response.body).to include(project_recurring_meeting_path(project, recurring_meeting))

      expect(recurring_meeting.scheduled_meetings.count).to eq(1)
      first = recurring_meeting.scheduled_meetings.first
      expect(first.start_time).to eq(DateTime.parse("2024-12-05T10:00:00Z"))
      expect(first.start_time).to eq(recurring_meeting.first_occurrence.to_time)

      meeting = first.meeting
      expect(meeting.agenda_items.count).to eq(1)
      expect(meeting.agenda_items.first.title).to eq("My template item")

      expect(RecurringMeetings::InitNextOccurrenceJob)
        .to have_been_enqueued.with(recurring_meeting, DateTime.parse("2024-12-06T10:00:00Z"))
                              .at(DateTime.parse("2024-12-05T10:00:00Z"))
    end
  end

  context "when first occurrence is already created" do
    let!(:meeting) { create(:meeting, recurring_meeting:, start_time: recurring_meeting.start_time) }
    let!(:schedule) do
      create :scheduled_meeting,
             meeting:,
             recurring_meeting:,
             start_time: recurring_meeting.start_time
    end

    it "does not create a new meeting" do
      expect { subject }.not_to change(recurring_meeting.scheduled_meetings, :count)
      expect(response).to redirect_to(project_recurring_meeting_path(project, recurring_meeting))

      expect(recurring_meeting.scheduled_meetings.count).to eq(1)
      first = recurring_meeting.scheduled_meetings.first.meeting
      expect(first).to eq(meeting)
    end
  end

  context "when first occurrence is cancelled" do
    let!(:schedule) do
      create :scheduled_meeting,
             :cancelled,
             recurring_meeting:,
             start_time: recurring_meeting.start_time
    end

    it "takes over that occurrence" do
      expect { subject }.to change(recurring_meeting.meetings, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="redirect_to"')
      expect(response.body).to include(project_recurring_meeting_path(project, recurring_meeting))

      expect(recurring_meeting.scheduled_meetings.count).to eq(1)
      first = recurring_meeting.scheduled_meetings.first
      expect(first).not_to be_cancelled
      expect(first.meeting).to be_present
    end
  end

  context "when user has no permissions to access" do
    let(:current_user) { create(:user) }

    it "does not authorize" do
      subject
      expect(response).to have_http_status(:forbidden)
    end
  end
end
