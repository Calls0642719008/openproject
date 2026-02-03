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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module CustomFields
  class DetailsForm < ApplicationForm
    form do |details_form|
      if model.new_record?
        details_form.hidden(
          name: :type,
          scope_name_to_model: false
        )

        details_form.hidden(
          name: :field_format
        )
      end

      details_form.text_field(
        name: :name,
        label: I18n.t(:label_name),
        required: true
      )

      if show_section_field?
        details_form.select_list(
          name: :custom_field_section_id,
          label: I18n.t("activerecord.attributes.project_custom_field.custom_field_section"),
          required: true
        ) do |list|
          ProjectCustomFieldSection.find_each do |cs|
            list.option(value: cs.id, label: cs.name)
          end
        end
      end

      if show_multi_value_field?
        details_form.check_box(
          name: :multi_value,
          label: label(:multi_value),
          caption: instructions(:multi_select)
        )
      end

      if show_formula_field?
        details_form.pattern_input(
          name: :formula,
          value: model.formula_string,
          suggestions: formula_suggestions,
          label: I18n.t(:label_formula),
          required: true,
          caption: instructions(:formula)
        )
      end

      if show_default_bool_field?
        details_form.check_box(
          name: :default_value,
          label: label(:default_value)
        )
      end

      if show_is_required_field?
        details_form.check_box(
          name: :is_required,
          label: label(:is_required),
          caption: instructions(:is_required)
        )
      end

      if show_is_for_all_field?
        details_form.check_box(
          name: :is_for_all,
          label: label(:is_for_all),
          caption: instructions(:is_for_all)
        )
      end

      if show_is_filter_field?
        details_form.check_box(
          name: :is_filter,
          label: label(:is_filter),
          caption: instructions(:is_filter)
        )
      end

      if show_admin_only_field?
        details_form.check_box(
          name: :admin_only,
          label: label(:admin_only),
          caption: instructions(:admin_only)
        )
      end

      if show_editable_field?
        details_form.check_box(
          name: :editable,
          label: label(:editable),
          caption: instructions(:editable)
        )
      end

      details_form.submit(name: :submit, label: I18n.t(:button_save), scheme: :default)
    end

    def label(field)
      I18n.t("activerecord.attributes.custom_field.#{field}")
    end

    def instructions(field)
      key = if model.is_a?(ProjectCustomField)
              "custom_fields.instructions.#{field}.project"
            else
              "custom_fields.instructions.#{field}.all"
            end

      I18n.t(key)
    end

    def show_section_field?
      model.is_a?(ProjectCustomField)
    end

    def show_default_bool_field?
      %w[bool].include?(model.field_format)
    end

    def show_is_required_field?
      %w[calculated_value bool].exclude?(model.field_format)
    end

    def show_multi_value_field?
      model.multi_value_possible?
    end

    def show_formula_field?
      %w[calculated_value].include?(model.field_format)
    end

    def show_is_for_all_field?
      model.is_a?(WorkPackageCustomField) || model.is_a?(ProjectCustomField)
    end

    def show_is_filter_field?
      model.is_a?(WorkPackageCustomField)
    end

    def show_admin_only_field?
      model.is_a?(ProjectCustomField) || model.is_a?(UserCustomField)
    end

    def show_editable_field?
      model.is_a?(UserCustomField)
    end

    def formula_suggestions
      operators = CustomField::CalculatedValue::MATH_OPERATORS_FOR_FORMULA
                    # Hide % from the suggestions as it can be used as either modulo or percentage.
                    .reject { it == "%" }
                    .map do |op|
        # Insert operators as plain text nodes instead of tokens, since displaying them as tokens would result
        # in too much visual clutter. We still want to offer autocompletion for them.
        { key: op, label: op, insert_as_text: true, enabled: true }
      end

      custom_fields = model.usable_custom_field_references_for_formula.map do |cf|
        { key: "cf_#{cf.id}", label: cf.name, enabled: true }
      end

      {
        custom_fields: { title: I18n.t("label_custom_field_plural"), tokens: custom_fields },
        operators: { title: I18n.t("label_mathematical_operators"), tokens: operators }
      }
    end
  end
end
