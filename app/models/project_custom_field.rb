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

class ProjectCustomField < CustomField
  belongs_to :project_custom_field_section, class_name: "ProjectCustomFieldSection", foreign_key: :custom_field_section_id,
                                            inverse_of: :custom_fields
  has_many :project_custom_field_project_mappings, class_name: "ProjectCustomFieldProjectMapping", foreign_key: :custom_field_id,
                                                   dependent: :destroy, inverse_of: :project_custom_field
  has_many :projects, through: :project_custom_field_project_mappings

  acts_as_list column: :position_in_custom_field_section, scope: [:custom_field_section_id]

  after_save :activate_required_field_in_all_projects, if: :is_for_all?

  validates :custom_field_section_id, presence: true

  # Relevant for user fields to allow membership assignment
  has_one :custom_fields_role, foreign_key: :custom_field_id, dependent: :destroy, inverse_of: :custom_field
  has_one :role, through: :custom_fields_role
  accepts_nested_attributes_for :custom_fields_role, allow_destroy: true

  scope :user_field_with_assigned_role, -> do
    joins(:custom_fields_role)
      .where.not(custom_fields_roles: { role_id: nil })
      .where(field_format: "user")
  end

  class << self
    def visible(user = User.current, project: nil)
      if user.admin?
        all
      elsif user.allowed_in_any_project?(:select_project_custom_fields) || user.allowed_globally?(:add_project)
        where(admin_only: false)
      else
        where(admin_only: false).where(mappings_with_view_project_attributes_permission(user, project).exists)
      end
    end

    private

    def mappings_with_view_project_attributes_permission(user, project) # rubocop:disable Metrics/AbcSize
      allowed_projects = Project.allowed_to(user, :view_project_attributes)
      mapping_table = ProjectCustomFieldProjectMapping.arel_table

      mapping_condition = mapping_table[:custom_field_id].eq(arel_table[:id])
                          .and(mapping_table[:project_id].in(allowed_projects.select(:id).arel))

      if project&.persisted?
        mapping_condition = mapping_condition.and(mapping_table[:project_id].eq(project.id))
      end

      mapping_table.project(Arel.star).where(mapping_condition)
    end
  end

  def type_name
    :label_project_plural
  end

  def role_id
    role&.id
  end

  def role=(role)
    self.role_id = role&.id
  end

  def role_id=(role_id)
    if role_id.present?
      build_custom_fields_role unless custom_fields_role
      custom_fields_role.role_id = role_id
    else
      custom_fields_role&.mark_for_destruction
    end
  end

  def activate_required_field_in_all_projects
    ProjectCustomFieldProjectMapping.upsert_all(
      Project.pluck(:id).map { |project_id| { project_id:, custom_field_id: id } },
      unique_by: %i[custom_field_id project_id]
    )
  end
end
