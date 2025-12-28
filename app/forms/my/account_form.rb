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

class My::AccountForm < ApplicationForm
  form do |f|
    f.text_field(
      name: :username,
      label: User.human_attribute_name(:login),
      input_width: :small,
      value: @user.login,
      readonly: true
    )

    f.text_field(
      name: :firstname,
      label: User.human_attribute_name(:firstname),
      input_width: :small,
      disabled: @login_via_provider || @login_via_ldap,
      caption: name_caption,
      required: true,
      autocomplete: "given-name"
    )

    f.text_field(
      name: :lastname,
      label: User.human_attribute_name(:lastname),
      input_width: :small,
      disabled: @login_via_provider || @login_via_ldap,
      caption: name_caption,
      required: true,
      autocomplete: "family-name"
    )

    f.text_field(
      name: :mail,
      type: :email,
      label: User.human_attribute_name(:mail),
      input_width: :small,
      disabled: @login_via_ldap,
      caption: @login_via_ldap ? I18n.t("user.text_change_disabled_for_ldap_login") : nil,
      required: true,
      autocomplete: "email"
    )
  end

  def initialize(user:)
    super()
    @user = user
    @login_via_provider = !!@user.identity_url
    @login_via_ldap = !!@user.ldap_auth_source_id
  end

  def name_caption
    if @login_via_provider
      I18n.t("user.text_change_disabled_for_provider_login")
    elsif @login_via_ldap
      I18n.t("user.text_change_disabled_for_ldap_login")
    end
  end
end
