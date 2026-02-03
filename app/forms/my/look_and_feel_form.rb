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

class My::LookAndFeelForm < ApplicationForm
  include ApplicationHelper

  form do |f|
    f.select_list(
      name: :theme,
      label: attribute_name(:theme),
      caption: attribute_name(:mode_guideline),
      required: true,
      include_blank: false,
      input_width: :small,
      data: {
        my__look_and_feel_target: "themeSelect",
        action: "my--look-and-feel#updateContrastOptions"
      }
    ) do |select|
      theme_options_for_select.each { |(label, value)| select.option(value:, label:) }
    end

    f.check_box_group(data: { my__look_and_feel_target: "autoThemeContrast" }) do |group|
      group.check_box name: :force_light_theme_contrast,
                      label: attribute_name(:force_light_theme_contrast),
                      caption: attribute_name(:force_light_theme_contrast_caption)
      group.check_box name: :force_dark_theme_contrast,
                      label: attribute_name(:force_dark_theme_contrast),
                      caption: attribute_name(:force_dark_theme_contrast_caption)
    end

    f.check_box_group(data: { my__look_and_feel_target: "singleThemeContrast" }) do |group|
      group.check_box name: :increase_theme_contrast,
                      label: attribute_name(:increase_contrast),
                      caption: attribute_name(:increase_contrast_caption)
    end

    f.select_list(
      name: :comments_sorting,
      label: attribute_name(:comments_sorting),
      required: true,
      include_blank: false,
      input_width: :small
    ) do |select|
      comment_sort_order_options.each { |(label, value)| select.option(value:, label:) }
    end

    f.check_box name: :disable_keyboard_shortcuts,
                label: attribute_name(:disable_keyboard_shortcuts),
                caption: disable_keyboard_shortcuts_caption

    f.submit(name: :submit,
             label: attribute_name(:button_update_look_and_feel),
             scheme: :default)
  end

  private

  def disable_keyboard_shortcuts_caption
    attribute_name(:disable_keyboard_shortcuts_caption_html,
                   href: OpenProject::Static::Links.url_for(:shortcuts)).html_safe # rubocop:disable Rails/OutputSafety
  end
end
