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

class DocumentsController < ApplicationController
  include AttachableServiceCall
  include FlashMessagesOutputSafetyHelper
  include PaginationHelper
  include OpTurbo::ComponentStream

  default_search_scope :documents
  model_object Document

  before_action :find_project_by_project_id, only: %i[index search new create]
  before_action :find_model_object, except: %i[index search new create]
  before_action :find_project_from_association, except: %i[index search new create]
  before_action :authorize

  def index
    @documents = list_documents_query
      .includes(:type)
      .paginate(page: page_param, per_page: per_page_param)
  end

  def search
    index
    replace_via_turbo_stream component: Documents::ListComponent.new(@documents, project: @project)
    current_url = url_for(params.permit(:controller, :filters, :sortBy).merge(action: "index"))
    turbo_streams << turbo_stream.push_state(current_url)

    respond_with_turbo_streams
  end

  def show
    @attachments = @document.attachments.order(Arel.sql("created_at DESC"))

    if @document.collaborative? && Setting.real_time_text_collaboration_enabled?
      generate_encrypted_oauth_token
      derive_readonly_from_permissions
      derive_show_edit_state_from_params
    end
  end

  def render_avatars
    user_ids = params[:user_ids]
    @users = User.where(id: user_ids)
    update_via_turbo_stream(component: Documents::ShowEditView::PageHeader::LiveUsersComponent.new(users: @users))

    respond_with_turbo_streams
  end

  def render_last_saved_at
    update_via_turbo_stream(component: Documents::ShowEditView::PageHeader::LiveSavedAtComponent.new(@document))

    respond_with_turbo_streams
  end

  def render_connection_error
    update_via_turbo_stream(component: Documents::ShowEditView::ConnectionErrorNoticeComponent.new)

    respond_with_turbo_streams
  end

  def render_connection_recovery
    render_success_flash_message_via_turbo_stream(
      message: I18n.t("documents.show_edit_view.connection_recovery_notice.description"),
      unique_key: "document-connection-recovery-notice-#{@document.id}"
    )

    respond_with_turbo_streams
  end

  def new
    @document = @project.documents.build
    @document.attributes = document_params
  end

  def edit
    render_400 unless @document.classic?
  end

  def edit_title
    update_header_component_via_turbo_stream(state: :edit)

    respond_with_turbo_streams
  end

  def create
    if document_params[:kind] == "classic"
      create_classic_document
    else
      create_collaborative_document
    end
  end

  def cancel_title_edit
    update_header_component_via_turbo_stream(state: :show)

    respond_with_turbo_streams
  end

  def update
    call = attachable_update_call ::Documents::UpdateService,
                                  model: @document,
                                  args: document_params

    if call.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to action: "show", id: @document
    else
      @document = call.result
      render action: :edit, status: :unprocessable_entity
    end
  end

  def update_title
    call = Documents::UpdateService
      .new(user: current_user, model: @document)
      .call(document_params.slice(:title))

    state = call.success? ? :show : :edit
    update_header_component_via_turbo_stream(state:)

    respond_with_turbo_streams
  end

  def update_type
    service_call = Documents::UpdateService
      .new(user: current_user, model: @document)
      .call(type_id: params[:type_id])

    if service_call.success?
      update_via_turbo_stream(
        component: Documents::ShowEditView::PageHeader::InfoLineComponent.new(@document)
      )
    else
      render_error_flash_message_via_turbo_stream(
        message: service_call.errors.full_messages
      )
      @turbo_status = :unprocessable_entity
    end

    respond_with_turbo_streams
  end

  def delete_dialog
    respond_with_dialog Documents::DeleteDialogComponent.new(@document)
  end

  def destroy
    service_call = Documents::DeleteService
      .new(user: current_user, model: @document)
      .call

    if service_call.success?
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = join_flash_messages(service_call.errors.full_messages)
    end

    redirect_to project_documents_path(@project), status: :see_other
  end

  private

  def document_params
    params.fetch(:document, {}).permit("type_id", "title", "description", "content_binary", "kind")
  end

  def list_documents_query
    @query = ParamsToQueryService.new(Document, current_user).call(params)
    @query.where(:project_id, "=", [@project.id])
    @query.order(updated_at: :desc) unless params[:sortBy]

    @query.results
  end

  def create_classic_document
    call = attachable_create_call ::Documents::CreateService,
                                  args: document_params.merge(project: @project)

    if call.success?
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_documents_path(@project)
    else
      @document = call.result
      render action: :new, status: :unprocessable_entity
    end
  end

  def create_collaborative_document
    call = ::Documents::CreateService
        .new(user: current_user)
        .call(title: I18n.t(:label_document_new), project: @project, type_id: DocumentType.default.id)

    redirect_to document_path(call.result, state: :edit)
  end

  # rubocop:disable Metrics/AbcSize
  def generate_encrypted_oauth_token
    if !current_user.allowed_in_project?(:view_documents, @project)
      return
    end

    result = Documents::OAuth::GenerateTokenService
      .new(user: current_user)
      .call

    if result.failure?
      Rails.logger.error("Failed to generate OAuth token for document #{@document.id}: #{result.errors}")
      return
    end

    result = Documents::OAuth::EncryptTokenService
      .new(token: result.result.plaintext_token)
      .call

    if result.failure?
      Rails.logger.error("Failed to encrypt OAuth token for document #{@document.id}: #{result.errors}")
      return
    end

    @oauth_token = result.result
  end
  # rubocop:enable Metrics/AbcSize

  def update_header_component_via_turbo_stream(state: :show)
    update_via_turbo_stream(
      component: Documents::ShowEditView::PageHeaderComponent.new(@document, project: @project, state:)
    )
  end

  def derive_show_edit_state_from_params
    @state = params[:state] == "edit" ? :edit : :show
  end

  def derive_readonly_from_permissions
    @readonly = current_user.allowed_in_project?(:view_documents, @project) &&
      !current_user.allowed_in_project?(:manage_documents, @project)
  end
end
