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

module MeetingParticipants
  class DeleteService < BaseServices::Delete
    protected

    def after_validate(call)
      send_notifications if should_send_notification?

      call
    end

    def send_notifications
      remaining_participants = fetch_remaining_participants

      send_cancellation_notification(model)
      notify_remaining_participants(model.meeting, remaining_participants, model.user)
    end

    def fetch_remaining_participants
      model.meeting.participants.invited
           .where.not(id: model.id)
           .includes(:user).to_a
    end

    def send_cancellation_notification(participant)
      meeting = participant.meeting

      if meeting.template?
        MeetingMailer.cancelled_series(meeting.recurring_meeting, participant.user, user).deliver_later
      else
        MeetingMailer.cancelled(meeting, participant.user, user).deliver_later
      end
    end

    def notify_remaining_participants(meeting, remaining_participants, removed_user)
      removed_participant_name = removed_user.name

      remaining_participants.each do |participant|
        send_participant_removed_notification(meeting, participant.user, removed_participant_name)
      end
    end

    def send_participant_removed_notification(meeting, recipient, removed_participant_name)
      if meeting.template?
        MeetingSeriesMailer.participant_removed(meeting.recurring_meeting, recipient, user,
                                                removed_participant: removed_participant_name).deliver_later
      else
        MeetingMailer.participant_removed(meeting, recipient, user,
                                          removed_participant: removed_participant_name).deliver_later
      end
    end

    def should_send_notification?
      Journal::NotificationConfiguration.active? && model.meeting.send_emails?
    end
  end
end
