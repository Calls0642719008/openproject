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

RSpec.describe RecurringMeetings::InitOccurrenceService, type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %i[meetings]) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i(view_meetings edit_meetings) })
  end
  shared_let(:series, refind: true) do
    create(:recurring_meeting,
           project:,
           start_time: Time.zone.tomorrow + 10.hours,
           frequency: "daily",
           interval: 1,
           end_after: "specific_date",
           end_date: 1.month.from_now)
  end

  let(:instance) { described_class.new(recurring_meeting: series, user: User.system) }
  let(:params) do
    { start_time: start_time }
  end

  let(:service_result) { instance.call(**params) }
  let(:created_meeting) { service_result.result }
  let(:scheduled_meeting) { created_meeting.scheduled_meeting }

  describe "handling the interim responses" do
    let(:start_time) { series.start_time + 10.days }

    let!(:participant) do
      series.template.participants.create!(
        user:,
        participation_status: :accepted,
        invited: true
      )
    end

    let!(:interim_response) do
      RecurringMeetingInterimResponse.create!(
        recurring_meeting: series,
        user: user,
        participation_status: :declined,
        start_time: start_time,
        comment: "I can normally come, but this time not."
      )
    end

    let!(:irrelevant_interim_response) do
      RecurringMeetingInterimResponse.create!(
        recurring_meeting: series,
        user: user,
        participation_status: :tentative,
        start_time: start_time + 10.days,
        comment: "Might be able to make it."
      )
    end

    it "moves the interim response to the created meeting's participant" do
      expect(service_result).to be_success

      participant = created_meeting.participants.find_by(user:)

      expect(participant).to be_present
      expect(participant).to be_participation_declined
      expect(participant.comment).to eq("I can normally come, but this time not.")

      # Ensure the interim response is deleted
      expect { interim_response.reload }.to raise_error(ActiveRecord::RecordNotFound)

      # Ensure the irrelevant interim response is untouched
      irrelevant = RecurringMeetingInterimResponse.find(irrelevant_interim_response.id)
      expect(irrelevant).not_to be_nil
    end
  end
end
