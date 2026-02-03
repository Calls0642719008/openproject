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

module RecurringMeetings
  class TemplateCompletedService < ::BaseServices::BaseCallable
    def initialize(user:, recurring_meeting:)
      super()

      @user = user
      @recurring_meeting = recurring_meeting
    end

    protected

    def perform
      notify = params.fetch(:notify)
      first_occurrence = params.fetch(:first_occurrence)

      call = update_template(notify)
      init_first_occurrence(call, first_occurrence) if call.success?

      call
    end

    def update_template(notify)
      ::Meetings::UpdateService
        .new(user: @user, model: @recurring_meeting.template)
        .call({ state: "open", notify: })
    end

    def init_first_occurrence(call, first_occurrence)
      init_call = ::RecurringMeetings::InitOccurrenceService
                    .new(user: @user, recurring_meeting: @recurring_meeting)
                    .call(start_time: first_occurrence)

      call.merge!(init_call)
    end
  end
end
