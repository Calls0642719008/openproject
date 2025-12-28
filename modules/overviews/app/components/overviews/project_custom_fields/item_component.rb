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

module Overviews
  module ProjectCustomFields
    class ItemComponent < ApplicationComponent
      include ApplicationHelper
      include CalculatedValues::ErrorsHelper
      include CustomFieldsHelper
      include OpPrimer::ComponentHelpers

      def initialize(project_custom_field:, project_custom_field_values:, project:)
        super

        @project_custom_field = project_custom_field
        @project_custom_field_values = Array(project_custom_field_values)
        @project = project
      end

      private

      def allowed_to_edit?
        User.current.allowed_in_project?(:edit_project_attributes, @project)
      end

      def authorized_edit_wrapper
        if calculated_value? && allowed_to_edit?
          calculated_field_wrapper
        elsif allowed_to_edit?
          editable_wrapper
        else
          Primer::Beta::Text.new
        end
      end

      def editable_wrapper
        Primer::Beta::Text.new(
          tag: :div,
          classes: "project-custom-field-clickable",
          data: {
            controller: "project-custom-field-edit async-dialog",
            "project-custom-field-edit-url-value": edit_project_custom_field_path(project_id: @project.id,
                                                                                  id: @project_custom_field.id),
            action: "click->project-custom-field-edit#openEditDialog " \
                    "keydown.enter->project-custom-field-edit#openEditDialog " \
                    "keydown.space->project-custom-field-edit#openEditDialog " \
                    "project-custom-field-edit:open-dialog->async-dialog#handleOpenDialog"
          },
          aria: {
            label: [
              I18n.t(:label_edit_x, x: @project_custom_field.name),
              I18n.t(:label_value_x, x: accessible_value_text)
            ].join(", ")
          },
          role: "button",
          tabindex: 0,
          test_selector: "project-custom-field-edit-button-#{@project_custom_field.id}"
        )
      end

      def calculated_field_wrapper
        Primer::Beta::Text.new(
          tag: :div,
          id: calculated_value_tooltip_id,
          classes: "project-custom-field-non-editable",
          aria: {
            disabled: true,
            label: [
              @project_custom_field.name,
              I18n.t(:label_value_x, x: accessible_value_text)
            ].join(", ")
          },
          tabindex: 0
        )
      end

      def required?
        @project_custom_field.required? && !@project_custom_field.calculated_value?
      end

      def not_set?
        @project_custom_field_values.none?(&:value?)
      end

      def calculated_value?
        @project_custom_field.calculated_value?
      end

      def calculation_error?
        @project_custom_field.first_calculation_error(@project).present?
      end

      def render_calculation_error
        error = @project_custom_field.first_calculation_error(@project)

        render(Primer::OpenProject::FlexLayout.new(align_items: :flex_start,
                                                   data: {
                                                     test_selector: "error-cf-#{@project_custom_field.id}"
                                                   })) do |container|
          container.with_column do
            render Primer::Beta::Octicon.new(icon: :"alert-fill", color: :danger)
          end
          container.with_column(ml: 2) do
            render Primer::Beta::Text.new(color: :danger) do
              calculated_value_error_msg(error)
            end
          end
        end
      end

      def render_calculated_value_tooltip
        render Primer::Alpha::Tooltip.new(
          for_id: calculated_value_tooltip_id,
          type: :description,
          text: I18n.t("custom_fields.calculated_field_not_editable"),
          direction: :s
        )
      end

      def calculated_value_tooltip_id
        calculated_value? ? "calculated-field-tooltip-#{@project_custom_field.id}" : nil
      end

      def render_value
        case @project_custom_field.field_format
        when "link"
          render_link
        when "text"
          render_long_text
        when "user"
          render_user
        else
          render_custom_field_values
        end
      end

      def render_long_text
        render OpenProject::Common::AttributeComponent.new("dialog-cf-#{@project_custom_field.id}",
                                                           @project_custom_field.name,
                                                           @project_custom_field_values.first&.value,
                                                           lines: 3)
      end

      def render_user
        if @project_custom_field.multi_value?
          flex_layout do |avatar_container|
            @project_custom_field_values.each do |cf_value|
              avatar_container.with_row do
                render_avatar(cf_value.typed_value)
              end
            end
          end
        else
          render_avatar(@project_custom_field_values.first&.typed_value)
        end
      end

      def render_avatar(user)
        render(Users::AvatarComponent.new(user:, size: :mini))
      end

      def render_link
        href = @project_custom_field_values.first&.value
        link = Addressable::URI.parse(href)
        return href unless link

        target = link.host == Setting.host_without_protocol ? "_top" : "_blank"
        render(Primer::Beta::Link.new(href:, rel: "noopener noreferrer", target:)) do
          href
        end
      end

      def render_custom_field_values
        render(Primer::Beta::Text.new) { custom_field_values }
      end

      def accessible_value_text
        return I18n.t("placeholders.default") if not_set?
        custom_field_values
      end

      def custom_field_values
        return @custom_field_values if defined?(@custom_field_values)

        values = @project_custom_field_values.map { |v| format_value(v.value, @project_custom_field) }

        @custom_field_values = @project_custom_field.multi_value? ? values.join(", ") : values.first
      end
    end
  end
end
