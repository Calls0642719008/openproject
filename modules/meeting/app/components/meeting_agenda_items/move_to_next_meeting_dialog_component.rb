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

module MeetingAgendaItems
  class MoveToNextMeetingDialogComponent < ApplicationComponent
    include ApplicationHelper
    include OpTurbo::Streamable

    def initialize(agenda_item:, datetime:, skipped: nil)
      super

      @agenda_item = agenda_item
      @datetime = datetime
      @skipped = skipped
    end

    private

    def title = I18n.t(:label_agenda_item_move_to_next_title)

    def confirmation_message
      base_message = I18n.t(
        :text_agenda_item_move_next_meeting,
        date: format_date(@datetime),
        time: format_time(@datetime, include_date: false)
      )

      if @skipped.present?
        "#{base_message}\n\n#{skipped_message}"
      else
        base_message
      end
    end

    def skipped_message
      if @skipped.one?
        I18n.t(:text_agenda_item_dialog_skipping_cancelled_one, date: format_date(DateTime.iso8601(@skipped.first)))
      else
        I18n.t(:text_agenda_item_dialog_skipping_cancelled_many, count: @skipped.size)
      end
    end
  end
end
