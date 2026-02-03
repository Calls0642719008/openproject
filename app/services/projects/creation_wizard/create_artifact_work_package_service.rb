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

module Projects::CreationWizard
  class CreateArtifactWorkPackageService < ::BaseServices::BaseContracted
    include Contracted
    include ProjectHelper
    include ArtifactExporter
    include Rails.application.routes.url_helpers
    prepend Projects::Concerns::UpdateDemoData

    def initialize(user:, model:, contract_class: Projects::CreateArtifactWorkPackageContract)
      super(user:, contract_class:)
      self.model = model
      @skip_creation = false
    end

    def project = model

    private

    attr_accessor :artifact_work_package

    def skip_creation? = @skip_creation
    def skip_creation! = @skip_creation = true

    def before_perform(service_call)
      if WorkPackage.exists?(project.project_creation_wizard_artifact_work_package_id)
        skip_creation!
      end

      service_call
    end

    def validate_contract(service_call)
      return service_call if skip_creation?

      super
    end

    def persist(service_call)
      return service_call if skip_creation?

      creation_call = create_artifact_work_package

      creation_call.on_success do
        self.artifact_work_package = creation_call.result
        project.project_creation_wizard_artifact_work_package_id = artifact_work_package.id
        project.save
      end
      creation_call.on_failure do
        service_call.errors.add(:base, I18n.t("projects.wizard.create_artifact_work_package_error"))
        service_call.merge!(creation_call)
      end

      service_call
    end

    def after_perform(service_call)
      send_notification_email

      return service_call if store_attachment_locally? || skip_creation?

      if project_storage.nil?
        service_call.errors.add(:base, I18n.t("projects.wizard.create_artifact_storage_error"))
        return service_call
      end

      storage_call = upload_artifact_to_storage

      storage_call.on_failure do
        service_call.merge!(storage_call, without_success: true)
      end

      service_call
    end

    def send_notification_email
      return unless project.project_creation_wizard_send_confirmation_email

      ProjectArtifactsMailer
        .creation_wizard_submitted(user, project, artifact_work_package)
        .deliver_later
    end

    def create_artifact_work_package
      create_params = {
        project:,
        type_id: project.project_creation_wizard_work_package_type_id,
        status_id: project.project_creation_wizard_status_when_submitted_id,
        subject:,
        assigned_to_id:,
        journal_notes:,
        description:
      }

      create_params[:attachments] = [pdf_attachment] if store_attachment_locally?
      WorkPackages::CreateService.new(user:, contract_options: { skip_custom_field_validation: true }).call(create_params)
    end

    def journal_notes
      <<~COMMENT
        #{mention_tag(assignee_user)}

        #{project.project_creation_wizard_work_package_comment}

        #{wizard_relative_link}
      COMMENT
    end

    def subject
      I18n.t(project.project_creation_wizard_artifact_name,
             default: ::Projects::CreationWizard::DEFAULT_ARTIFACT_NAME_OPTION.to_sym,
             scope: "settings.project_initiation_request.name.options")
    end

    def description
      <<~DESCRIPTION
        #{description_template}

        #{wizard_relative_link}
      DESCRIPTION
    end

    def description_template
      I18n.t("settings.project_initiation_request.submission.description_template",
             wizard_name: project_creation_wizard_name(project))
    end

    def assigned_to_id
      project.custom_value_for(assignee_custom_field).value
    end

    def assignee_user
      User.find(assigned_to_id)
    end

    def assignee_custom_field
      return @assignee_custom_field if defined?(@assignee_custom_field)

      @assignee_custom_field = project.available_custom_fields
                                      .find_by(id: project.project_creation_wizard_assignee_custom_field_id)
    end

    def pdf_attachment
      export = create_pdf_export!
      file = OpenProject::Files.create_uploaded_file(
        name: export.title,
        content_type: export.mime_type,
        content: export.content,
        binary: true
      )

      Attachment.new(
        container: nil,
        author: user,
        file:
      )
    end

    def mention_tag(user)
      ApplicationController.helpers.content_tag(
        "mention",
        "@#{user.name}",
        class: "mention",
        data: {
          id: user.id,
          type: "user",
          text: "@#{user.name}"
        }
      )
    end

    def wizard_relative_link
      artifact_key = project.project_creation_wizard_artifact_name || "project_initiation_request"
      link_text = I18n.t(
        "settings.project_initiation_request.wizard_status_button.#{artifact_key}",
        default: I18n.t("settings.project_initiation_request.wizard_status_button.project_initiation_request")
      )
      "[#{link_text}](#{project_creation_wizard_path(project)})"
    end
  end
end
