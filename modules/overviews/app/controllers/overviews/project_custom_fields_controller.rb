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

class Overviews::ProjectCustomFieldsController < ApplicationController
  include OpTurbo::ComponentStream

  before_action :find_project_by_project_id
  before_action :find_project_custom_field
  before_action :authorize

  def edit
    respond_with_dialog(
      Overviews::ProjectCustomFields::EditDialogComponent.new(
        project: @project,
        project_custom_field: @custom_field
      )
    )
  end

  def update
    # FIXME: submitted format of form parameters are not configurable for the tree view component. Hence, we
    # need to process it before giving them in standard format to the update service.
    if @custom_field.hierarchical_list?
      process_hierarchy_params
    end

    service_call = ::Projects::UpdateService
                    .new(
                      user: current_user,
                      model: @project,
                      contract_options: { project_attributes_only: true }
                    )
                    .call(permitted_params.project)

    if service_call.success?
      if field_shown_in_sidebar?(@custom_field)
        update_sidebar_component
      else
        update_widgets_component
      end
    else
      handle_errors(service_call.result, @custom_field)
    end

    respond_to_with_turbo_streams(status: service_call.success? ? :ok : :unprocessable_entity)
  end

  private

  def process_hierarchy_params
    values = params.dig(:project, :custom_field_values)

    ids = Array(values).reject(&:empty?).map do |value|
      MultiJson.load(value, symbolize_keys: true)[:value]
    end

    params[:project][:custom_field_values] = { @custom_field.id.to_s => ids.one? ? ids.first : ids }
  end

  def find_project_custom_field
    @custom_field = @project.available_custom_fields.find(params[:id])
  end

  def handle_errors(project_with_errors, custom_field)
    update_via_turbo_stream(
      component: Overviews::ProjectCustomFields::EditComponent.new(
        project: project_with_errors,
        project_custom_field: custom_field
      )
    )
  end

  def update_sidebar_component
    update_via_turbo_stream(
      component: Overviews::ProjectCustomFields::SidePanelComponent.new(project: @project)
    )
  end

  def update_widgets_component
    update_via_turbo_stream(
      component: Grids::ProjectAttributeWidgets.new(@project)
    )
  end

  def field_shown_in_sidebar?(custom_field)
    CustomFieldSection.find(custom_field.custom_field_section_id).shown_in_overview_sidebar?
  end
end
