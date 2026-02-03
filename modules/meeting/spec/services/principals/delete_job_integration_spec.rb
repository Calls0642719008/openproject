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

RSpec.describe Principals::DeleteJob, "Meetings", type: :model do
  subject(:job) { described_class.perform_now(principal) }

  shared_let(:deleted_user) do
    create(:deleted_user)
  end
  let(:principal) do
    create(:user)
  end

  context "with a meeting" do
    let!(:meeting) { create(:meeting, author: principal) }
    let!(:meeting_agenda_item) { create(:meeting_agenda_item, presenter: principal) }
    let!(:meeting_outcome) { create(:meeting_outcome, meeting_agenda_item:, author: principal) }
    let!(:recurring_meeting) { create(:recurring_meeting, author: principal) }

    it "rewrites the references" do
      job

      expect(meeting.reload.author).to eq deleted_user
      expect(meeting_agenda_item.reload.presenter).to eq deleted_user
      expect(meeting_outcome.reload.author).to eq deleted_user
      expect(recurring_meeting.reload.author).to eq deleted_user
    end
  end
end
