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

require "rails_helper"

RSpec.describe Admin::Settings::BacklogsSettingsForm, type: :forms do
  include_context "with rendered form"

  let(:form_arguments) { { url: "/foo", model: false, scope: :settings } }

  subject(:rendered_form) do
    vc_render_form
    page
  end

  it "renders", :aggregate_failures do
    expect(rendered_form).to have_element "select-panel", "data-dynamic-label-prefix": "Selected types"
    expect(rendered_form).to have_field "settings[story_types][]", type: :hidden, multiple: true

    expect(rendered_form).to have_element "select-panel", "data-dynamic-label-prefix": "Selected type"
    expect(rendered_form).to have_field "settings[task_type]", type: :hidden

    expect(rendered_form).to have_field "Template for sprint wiki page", type: :text do |field|
      expect(field["name"]).to eq "settings[wiki_template]"
    end

    expect(rendered_form).to have_field "Up", type: :radio do |field|
      expect(field["name"]).to eq "settings[points_burn_direction]"
      expect(field["value"]).to eq "up"
    end

    expect(rendered_form).to have_field "Down", type: :radio do |field|
      expect(field["name"]).to eq "settings[points_burn_direction]"
      expect(field["value"]).to eq "down"
    end

    expect(rendered_form).to have_button "Save", type: "submit"
  end
end
