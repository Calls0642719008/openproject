# frozen_string_literal: true

# -- copyright
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
# ++
require "spec_helper"

RSpec.describe CustomFields::DetailsComponent, type: :component do
  describe ".supported?" do
    context "with a bool cf" do
      let(:custom_field) { build_stubbed(:boolean_wp_custom_field) }

      it "is supported" do
        expect(described_class).to be_supported(custom_field)
      end
    end

    context "with a string cf" do
      let(:custom_field) { build_stubbed(:string_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a text cf" do
      let(:custom_field) { build_stubbed(:text_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a link cf" do
      let(:custom_field) { build_stubbed(:link_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with an int cf" do
      let(:custom_field) { build_stubbed(:integer_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a version cf" do
      let(:custom_field) { build_stubbed(:version_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a user cf" do
      let(:custom_field) { build_stubbed(:user_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a date cf" do
      let(:custom_field) { build_stubbed(:date_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a list cf" do
      let(:custom_field) { build_stubbed(:list_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a float cf" do
      let(:custom_field) { build_stubbed(:float_wp_custom_field) }

      it "is not supported" do
        expect(described_class).not_to be_supported(custom_field)
      end
    end

    context "with a calculated_value cf" do
      let(:custom_field) { build_stubbed(:calculated_value_project_custom_field) }

      it "is supported" do
        expect(described_class).to be_supported(custom_field)
      end
    end

    context "with a hierarchy cf" do
      let(:custom_field) { build_stubbed(:hierarchy_wp_custom_field) }

      it "is supported" do
        expect(described_class).to be_supported(custom_field)
      end
    end

    context "with a weighted_item_list cf" do
      let(:custom_field) { build_stubbed(:weighted_item_list_wp_custom_field) }

      it "is supported" do
        expect(described_class).to be_supported(custom_field)
      end
    end
  end
end
