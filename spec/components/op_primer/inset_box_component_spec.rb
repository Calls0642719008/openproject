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

RSpec.describe OpPrimer::InsetBoxComponent, type: :component do
  def render_component(**args)
    render_inline(described_class.new(**args))
  end

  context "with defaults" do
    subject(:rendered) { render_component }

    it "renders with default inset styles" do
      expect(rendered).to have_css(".color-bg-inset.p-3.rounded-2")
    end

    it "renders with border by default" do
      expect(rendered).to have_css(".border")
      expect(rendered).to have_no_css(".border-0")
    end
  end

  context "when border is false" do
    subject(:rendered) { render_component(border: false) }

    it "renders border-0 instead of border" do
      expect(rendered).to have_css(".border-0")
      expect(rendered).to have_no_css(".border")
    end
  end

  context "when custom classes are passed" do
    subject(:rendered) { render_component(classes: "my-extra-class") }

    it "applies custom classes" do
      expect(rendered).to have_css(".my-extra-class")
    end
  end
end
