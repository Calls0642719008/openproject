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
  class ItemComponent::ShowComponent < ApplicationComponent
    include ApplicationHelper
    include AvatarHelper
    include OpTurbo::Streamable
    include OpPrimer::ComponentHelpers
    include Redmine::I18n

    def initialize(meeting_agenda_item:,
                   first_and_last: [],
                   current_occurrence: nil,
                   presentation_mode: false)
      super

      @meeting_agenda_item = meeting_agenda_item
      @meeting = meeting_agenda_item.meeting
      @series = @meeting.recurring_meeting
      @first_and_last = first_and_last
      @current_occurrence = current_occurrence
      @presentation_mode = presentation_mode
    end

    def wrapper_uniq_by
      @meeting_agenda_item.id
    end

    private

    def presentation_mode?
      @presentation_mode
    end

    def drag_and_drop_enabled?
      return false if presentation_mode?

      !@meeting.closed? && User.current.allowed_in_project?(:manage_agendas, @meeting.project)
    end

    def can_manage_agendas?
      User.current.allowed_in_project?(:manage_agendas, @meeting.project)
    end

    def add_outcome_action?
      editable? &&
        @meeting.in_progress? &&
        !@meeting_agenda_item.in_backlog? &&
        User.current.allowed_in_project?(:manage_outcomes, @meeting.project)
    end

    def add_note_action?
      editable? && @meeting_agenda_item.notes.blank?
    end

    def first?
      @first ||=
        if @first_and_last.first
          @first_and_last.first == @meeting_agenda_item
        else
          @meeting_agenda_item.first?
        end
    end

    def last?
      @last ||=
        if @first_and_last.last
          @first_and_last.last == @meeting_agenda_item
        else
          @meeting_agenda_item.last?
        end
    end

    def meeting_closed?
      !@meeting.open?
    end

    def recurring_meeting?
      @series.present?
    end

    def edit_action_item(menu)
      return unless editable?

      menu.with_item(label: t("label_edit"),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->meetings--submit#intercept",
                       href: edit_meeting_agenda_item_path(@meeting_agenda_item.meeting,
                                                           @meeting_agenda_item,
                                                           presentation_mode: @presentation_mode,
                                                           current_occurrence: @current_occurrence),
                       method: "GET"
                     } }) do |item|
        item.with_leading_visual_icon(icon: :pencil)
      end
    end

    def add_note_action_item(menu)
      menu.with_item(label: t("label_agenda_item_add_notes"),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->meetings--submit#intercept",
                       href: edit_meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item,
                                                           display_notes_input: true, current_occurrence: @current_occurrence),
                       method: "GET"
                     } }) do |item|
        item.with_leading_visual_icon(icon: :note)
      end
    end

    def add_outcome_action_item(menu)
      menu.with_item(label: t("label_agenda_item_add_outcome"),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->meetings--submit#intercept",
                       href: new_meeting_outcome_path(@meeting_agenda_item.meeting,
                                                      meeting_agenda_item_id: @meeting_agenda_item&.id,
                                                      current_occurrence: @current_occurrence),
                       method: "GET"
                     } }) do |item|
        item.with_leading_visual_icon(icon: :plus)
      end
    end

    def copy_action_item(menu)
      url = meeting_url(@meeting, anchor: "meeting-agenda-item-#{@meeting_agenda_item.id}")
      menu.with_item(label: t("meeting.copy.to_clipboard"),
                     tag: :"clipboard-copy",
                     content_arguments: { value: url }) do |item|
        item.with_leading_visual_icon(icon: :copy)
      end
    end

    def move_to_next_meeting_action_item(menu)
      next_meeting_action_item(
        menu,
        label: t(:label_agenda_item_move_to_next),
        path_helper: :move_to_next_dialog_meeting_agenda_item_path,
        icon: "arrow-right"
      )
    end

    def duplicate_in_next_meeting_action_item(menu)
      next_meeting_action_item(
        menu,
        label: t(:label_agenda_item_duplicate_in_next),
        path_helper: :duplicate_in_next_dialog_meeting_agenda_item_path,
        icon: :duplicate
      )
    end

    def next_meeting_action_item(menu, label:, path_helper:, icon:)
      return unless editable?
      return if in_template?
      return if @series.nil?

      from_time = @meeting.start_time.past? ? Time.current : @meeting.start_time
      next_date = @series.next_occurrence(from_time:)
      return if next_date.nil?

      menu.with_item(
        label:,
        tag: :button,
        content_arguments: { data: {
          action: "click->meetings--submit#intercept",
          href: send(
            path_helper,
            @meeting_agenda_item.meeting,
            @meeting_agenda_item,
            datetime: next_date.iso8601
          ),
          method: "GET"
        } }
      ) do |item|
        item.with_leading_visual_icon(icon:)
      end
    end

    def move_actions(menu)
      return unless editable?

      move_action_item(menu, :highest, t("label_agenda_item_move_to_top"), "move-to-top") unless first?
      move_action_item(menu, :higher, t("label_agenda_item_move_up"), "chevron-up") unless first?
      move_action_item(menu, :lower, t("label_agenda_item_move_down"), "chevron-down") unless last?
      move_action_item(menu, :lowest, t("label_agenda_item_move_to_bottom"), "move-to-bottom") unless last?
    end

    def delete_action_item(menu)
      return unless editable?
      return if presentation_mode?

      label = @meeting_agenda_item.work_package_id.present? ? wp_agenda_item_delete_label : t(:text_destroy)
      menu.with_item(label:,
                     scheme: :danger,
                     href: meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item,
                                                    current_occurrence: @current_occurrence),
                     form_arguments: {
                       method: :delete, data: { turbo_confirm: t(:text_are_you_sure), "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon: :trash)
      end
    end

    def wp_agenda_item_delete_label
      @meeting_agenda_item.in_backlog? ? t(:label_agenda_item_remove_from_backlog) : t(:label_agenda_item_remove_from_agenda)
    end

    def move_action_item(menu, move_to, label_text, icon)
      menu.with_item(label: label_text,
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->meetings--submit#intercept",
                       href: move_meeting_agenda_item_path(
                         @meeting_agenda_item.meeting,
                         @meeting_agenda_item,
                         move_to:,
                         current_occurrence: @current_occurrence
                       )
                     } }) do |item|
        item.with_leading_visual_icon(icon:)
      end
    end

    def move_to_backlog_action_item(menu)
      return unless editable?

      menu.with_item(label: I18n.t(:label_agenda_item_move_to_backlog),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->meetings--submit#intercept",
                       href: drop_meeting_agenda_item_path(
                         @meeting_agenda_item.meeting,
                         @meeting_agenda_item,
                         type: :to_backlog,
                         current_occurrence: @current_occurrence
                       )
                     } }) do |item|
        item.with_leading_visual_icon(icon: "discussion-outdated")
      end
    end

    def move_to_current_meeting_action_item(menu)
      return unless editable?
      return if many_sections?

      menu.with_item(label: I18n.t(:label_agenda_item_move_to_current_meeting),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->meetings--submit#intercept",
                       href: drop_meeting_agenda_item_path(
                         @meeting_agenda_item.meeting,
                         @meeting_agenda_item,
                         type: :to_current,
                         current_occurrence: @current_occurrence
                       )
                     } }) do |item|
        item.with_leading_visual_icon(icon: "cross-reference")
      end
    end

    def move_to_section_action_item(menu)
      return unless editable?
      return unless many_sections?

      menu.with_item(label: I18n.t(:label_agenda_item_move_to_section),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->meetings--submit#intercept",
                       href: move_to_section_dialog_meeting_agenda_item_path(
                         @meeting_agenda_item.meeting,
                         @meeting_agenda_item,
                         current_occurrence: @current_occurrence
                       )
                     } }) do |item|
        item.with_leading_visual_icon(icon: "op-move")
      end
    end

    def notes_classes
      if @meeting.open?
        "op-uc-container override"
      else
        "op-uc-container override muted-color"
      end
    end

    def move_to_next_meeting_enabled?
      return false unless editable?

      @meeting.recurring? && @meeting.recurring_meeting&.next_occurrence.present? && !in_template?
    end

    def in_backlog?
      @meeting_agenda_item.meeting_section.backlog?
    end

    def in_template?
      @meeting.templated?
    end

    def move_to_different_section_or_meeting_action_added?
      return false unless editable?

      !in_template? || in_backlog? || move_to_next_meeting_enabled?
    end

    def editable?
      @editable ||= @meeting_agenda_item.editable? && can_manage_agendas?
    end

    def in_section?
      true
    end

    # def visible_sections?
    #   return true if @meeting.templated?
    #
    #   @meeting.sections.many?
    # end

    def many_sections?
      if @meeting_agenda_item.in_backlog? && @current_occurrence.present?
        @current_occurrence.sections.many?
      else
        @meeting.sections.many?
      end
    end
  end
end
