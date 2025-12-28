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

class MyController < ApplicationController
  include PasswordConfirmation
  include Accounts::UserPasswordChange
  include ActionView::Helpers::TagHelper
  include OpTurbo::ComponentStream
  include FlashMessagesOutputSafetyHelper

  layout "my"

  before_action :require_login
  before_action :set_current_user
  before_action :check_password_confirmation, only: %i[update_account]

  no_authorization_required! :account,
                             :update_account,
                             :locale,
                             :interface,
                             :update_settings,
                             :password,
                             :change_password,
                             :notifications,
                             :reminders

  menu_item :account, only: [:account]
  menu_item :locale, only: [:locale]
  menu_item :interface, only: [:interface]
  menu_item :password, only: [:password]
  menu_item :notifications, only: [:notifications]
  menu_item :reminders, only: [:reminders]

  def account; end

  def update_account
    write_settings
  end

  def locale; end

  def update_settings
    write_settings
  end

  def interface; end

  # Manage user's password
  def password
    @username = @user.login
    redirect_if_password_change_not_allowed_for(@user)
  end

  # When making changes here, also check AccountController.change_password
  def change_password
    change_password_flow(user: @user, params:, update_legacy: false) do
      redirect_to action: "password"
    end
  end

  # Configure user's in app notifications
  def notifications; end

  # Configure user's mail reminders
  def reminders; end

  private

  def redirect_if_password_change_not_allowed_for(user)
    unless user.change_password_allowed?
      flash[:error] = I18n.t(:notice_can_t_change_password)
      redirect_to action: "account"
      return true
    end
    false
  end

  def write_settings
    result = Users::UpdateService
               .new(user: current_user, model: current_user)
               .call(user_params)

    if result&.success
      flash[:notice] = notice_account_updated
      handle_email_changes
    else
      flash[:error] = error_account_update_failed(result)
    end

    redirect_back(fallback_location: my_account_path)
  end

  def handle_email_changes
    # If mail changed, expire all other sessions
    if @user.previous_changes["mail"]
      Users::DropTokensService.new(current_user: @user).call!
      Sessions::DropOtherSessionsService.call!(@user, session)

      flash[:info] = "#{flash[:notice]} #{t(:notice_account_other_session_expired)}"
      flash.delete :notice
    end
  end

  def user_params
    permitted_params.my_account_settings.to_h
  end

  def notice_account_updated
    OpenProject::LocaleHelper.with_locale_for(current_user) do
      t(:notice_account_updated)
    end
  end

  def error_account_update_failed(result)
    errors = result ? result.errors.full_messages.join("\n") : ""
    [t(:notice_account_update_failed), errors]
  end

  def set_current_user
    @user = current_user
  end

  def get_current_layout
    @user.pref[:my_page_layout] || DEFAULT_LAYOUT.dup
  end
end
