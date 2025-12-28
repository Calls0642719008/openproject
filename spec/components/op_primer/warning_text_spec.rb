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

RSpec.describe OpPrimer::WarningText, type: :component do
  def render_component(**, &)
    render_inline(described_class.new(**), &)
  end

  subject(:rendered_component) do
    render_component(show_warning_label:) { "Important Message" }
  end

  shared_examples "rendering container and icon" do
    it "renders container" do
      expect(rendered_component).to have_css "span:first-child"
    end

    it "applies inline flex styling" do
      expect(rendered_component).to have_css ".d-inline-flex.flex-items-center"
    end

    it "renders an icon" do
      expect(rendered_component).to have_octicon :"alert-fill", size: :xsmall, aria: { hidden: true }
    end
  end

  context "with default args" do
    let(:show_warning_label) { true }

    include_examples "rendering container and icon"

    it "renders text, including 'Warning:' prefix" do
      expect(rendered_component).to have_primer_text "Warning: Important Message", color: :attention do |text|
        expect(text).to have_css "strong", exact_text: "Warning:"
      end
    end
  end

  context "with show_warning_label: false" do
    let(:show_warning_label) { false }

    include_examples "rendering container and icon"

    it "renders just the text" do
      expect(rendered_component).to have_primer_text "Important Message", color: :attention
    end
  end

  context "with blank content" do
    subject(:rendered_component) do
      render_component { " " }
    end

    it "renders nothing" do
      expect(rendered_component.to_s).to be_empty
    end
  end
end
