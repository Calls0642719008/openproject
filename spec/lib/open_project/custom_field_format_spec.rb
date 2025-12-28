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

RSpec.describe OpenProject::CustomFieldFormat do
  describe ".available_for_class_name" do
    shared_examples_for "custom field formats" do |class_name, expected_formats|
      it "returns all custom field formats for the '#{class_name}' class", :aggregate_failures do
        formats = described_class.available_for_class_name(class_name)
        expect(formats).to all(be_a described_class)
        expect(formats.map(&:name)).to match_array(expected_formats)
      end
    end

    context "for a 'Project' class" do
      context "with some enterprise addons",
              with_ee: %i[calculated_values weighted_item_lists custom_field_hierarchies],
              with_flag: { calculated_value_project_attribute: true } do
        it_behaves_like "custom field formats",
                        "Project",
                        %w[bool calculated_value date float hierarchy int link list string text user version weighted_item_list]
      end

      context "without enterprise addons" do
        it_behaves_like "custom field formats",
                        "Project",
                        %w[bool date float int link list string text user version]
      end
    end

    context "for a 'WorkPackage' class" do
      context "with some enterprise addons", with_ee: %i[weighted_item_lists custom_field_hierarchies] do
        it_behaves_like "custom field formats",
                        "WorkPackage",
                        %w[bool date float hierarchy int link list weighted_item_list string text user version]
      end

      context "without enterprise addons" do
        it_behaves_like "custom field formats",
                        "WorkPackage",
                        %w[bool date float int link list string text user version]
      end
    end

    context "for a 'Version' class" do
      it_behaves_like "custom field formats",
                      "Version",
                      %w[bool date float int list string text user version]
    end

    context "for a 'TimeEntry' class" do
      it_behaves_like "custom field formats",
                      "TimeEntry",
                      %w[bool date float int list string text user version]
    end

    context "for a 'User' class" do
      it_behaves_like "custom field formats",
                      "User",
                      %w[bool date float int list string text]
    end

    context "for a 'Group' class" do
      it_behaves_like "custom field formats",
                      "Group",
                      %w[bool date float int list string text]
    end
  end

  describe ".available_formats" do
    shared_examples_for "available custom field formats" do |suffix, expected_formats|
      it "returns all custom field formats #{suffix}", :aggregate_failures do
        formats = described_class.available_formats
        expect(formats).to match_array(expected_formats)
      end
    end

    context "with a custom_field_hierarchies ee", with_ee: [:custom_field_hierarchies] do
      it_behaves_like "available custom field formats",
                      "including hierarchy",
                      %w[bool date float hierarchy int link list string text user version empty]
    end

    context "with a weighted item lists ee", with_ee: [:weighted_item_lists] do
      it_behaves_like "available custom field formats",
                      "including hierarchy",
                      %w[bool date float int link list string text user version weighted_item_list empty]
    end

    context "without a custom_field_hierarchies ee" do
      it_behaves_like "available custom field formats",
                      "excluding hierarchy",
                      %w[bool date float int link list string text user version empty]

      context "with a calculated values ee",
              with_ee: [:calculated_values],
              with_flag: { calculated_value_project_attribute: true } do
        it_behaves_like "available custom field formats",
                        "including calculated values",
                        %w[bool calculated_value date float int link list string text user version empty]
      end
    end
  end

  describe ".enabled_for_class_name" do
    shared_examples_for "custom field formats" do |class_name, expected_formats|
      it "returns all custom field formats for the '#{class_name}' class", :aggregate_failures do
        formats = described_class.enabled_for_class_name(class_name)
        expect(formats).to all(be_a described_class)
        expect(formats.map(&:name)).to match_array(expected_formats)
      end
    end

    context "for a 'Project' class" do
      context "with feature flags enabled", with_flag: { calculated_value_project_attribute: true } do
        it_behaves_like "custom field formats",
                        "Project",
                        %w[bool calculated_value date float hierarchy int link list string text user version weighted_item_list]
      end

      context "with no feature flags enabled", with_flag: {} do
        it_behaves_like "custom field formats",
                        "Project",
                        %w[bool date float hierarchy int link list string text user version weighted_item_list]
      end
    end
  end

  describe ".disabled_formats" do
    it "returns disabled formats" do
      formats = described_class.disabled_formats
      expect(formats).to match_array(%w[calculated_value])
    end

    context "with feature flags enabled", with_flag: { calculated_value_project_attribute: true } do
      it "returns no disabled formats" do
        formats = described_class.disabled_formats
        expect(formats).to be_empty
      end
    end
  end
end
