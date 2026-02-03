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

module Admin
  module Settings
    class BacklogsSettingsForm < ApplicationForm
      include ::Settings::FormHelper

      form do |f|
        f.select_panel(
          name: :story_types,
          label: I18n.t(:backlogs_story_type),
          title: I18n.t(:label_select_types),
          caption: setting_caption(:plugin_openproject_backlogs, :story_types),
          select_variant: :multiple,
          fetch_strategy: :local,
          dynamic_label: true,
          dynamic_label_prefix: I18n.t(:label_selected_types),
          data: {
            admin__backlogs_settings_target: "storyTypes"
          }
        ) do |select_menu|
          available_types.each do |label, value|
            active = value.in?(Story.types)
            in_use = Task.type == value

            select_menu.with_item(
              label:,
              content_arguments: { data: { value: } },
              active:,
              disabled: in_use,
              item_id: "type-#{value}",
              label_arguments: { classes: "__hl_inline_type_#{value}" }
            )
          end

          select_menu.with_footer(show_divider: true) do
            render(Primer::Beta::Button.new(scheme: :primary, data: { action: "click:select-panel#hide" })) do
              I18n.t(:button_apply)
            end
          end
        end

        f.select_panel(
          name: :task_type,
          label: I18n.t(:backlogs_task_type),
          title: I18n.t(:label_select_type),
          caption: setting_caption(:plugin_openproject_backlogs, :task_type),
          fetch_strategy: :local,
          dynamic_label: true,
          dynamic_label_prefix: I18n.t(:label_selected_type),
          data: {
            admin__backlogs_settings_target: "taskType"
          }
        ) do |select_menu|
          available_types.each do |label, value|
            active = Task.type == value
            in_use = value.in?(Story.types)

            select_menu.with_item(
              label:,
              content_arguments: { data: { value: } },
              active:,
              disabled: in_use,
              item_id: "type-#{value}",
              label_arguments: { classes: "__hl_inline_type_#{value}" }
            )
          end
        end

        f.radio_button_group(
          name: :points_burn_direction,
          label: I18n.t(:backlogs_points_burn_direction)
        ) do |group|
          group.radio_button(
            label: I18n.t(:label_points_burn_up),
            value: "up"
          )
          group.radio_button(
            label: I18n.t(:label_points_burn_down),
            value: "down"
          )
        end

        f.text_field(
          name: :wiki_template,
          label: I18n.t(:backlogs_wiki_template),
          input_width: :medium
        )

        f.submit(scheme: :primary, name: :apply, label: I18n.t(:button_save))
      end

      private

      def available_types
        Type.pluck(:name, :id)
      end
    end
  end
end
