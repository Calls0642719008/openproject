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

require "spec_helper"

RSpec.describe WorkPackage::PDFExport::WorkPackageListToPdf do
  include Redmine::I18n
  include PDFExportSpecUtils

  shared_let(:type_standard) { create(:type_standard) }
  shared_let(:type_bug) { create(:type_bug) }
  shared_let(:list_custom_field) do
    create(:list_wp_custom_field,
           types: [type_standard, type_bug],
           multi_value: true,
           possible_values: %w[Foo Bar])
  end
  shared_let(:text_custom_field_a) do
    create(:issue_custom_field, :text, types: [type_standard, type_bug], name: "Notes A")
  end
  shared_let(:text_custom_field_b) do
    create(:issue_custom_field, :text, types: [type_standard, type_bug], name: "Notes B")
  end
  shared_let(:link_custom_field) do
    create(:link_wp_custom_field, :link, types: [type_standard, type_bug], name: "My Link")
  end
  shared_let(:custom_value_first) do
    create(:work_package_custom_value,
           custom_field: list_custom_field,
           value: list_custom_field.custom_options.first.id)
  end
  shared_let(:types) { [type_standard, type_bug] }
  shared_let(:project) do
    create(:project,
           name: "Foo Bla. Report No. 4/2021 with/for Case 42",
           types:,
           work_package_custom_fields: [list_custom_field, text_custom_field_a, text_custom_field_b, link_custom_field])
  end
  shared_let(:user) do
    create(:user,
           member_with_permissions: { project => %w[view_work_packages export_work_packages] })
  end
  shared_let(:export_time) { DateTime.new(2023, 6, 30, 23, 59) }
  shared_let(:export_date_formatted) { format_date(export_time) }
  shared_let(:work_package_parent) do
    create(:work_package,
           project:,
           type: type_standard,
           subject: "Work package 1",
           story_points: 1,
           estimated_hours: 10,
           derived_estimated_hours: 20,
           remaining_hours: 7.5,
           derived_remaining_hours: 12.5,
           done_ratio: 25,
           derived_done_ratio: 38,
           description: "This is a description",
           text_custom_field_a.attribute_name => "Rich text 1.A",
           text_custom_field_b.attribute_name => "Rich text 1.B",
           list_custom_field.attribute_name => [
             list_custom_field.value_of("Foo"),
             list_custom_field.value_of("Bar")
           ],
           link_custom_field.attribute_name => "https://example.com")
  end
  shared_let(:work_package_child) do
    create(:work_package,
           project:,
           parent: work_package_parent,
           type: type_bug,
           subject: "Work package 2",
           estimated_hours: 10,
           remaining_hours: 5,
           done_ratio: 50,
           story_points: 2,
           description: "This is work package 2",
           text_custom_field_a.attribute_name => "Rich text 2.A",
           text_custom_field_b.attribute_name => "Rich text 2.B",
           list_custom_field.attribute_name => list_custom_field.value_of("Foo"),
           link_custom_field.attribute_name => "https://example.com")
  end
  let(:query_attributes) { {} }
  let!(:query) do
    build(:query, user:, project:, **query_attributes) do |q|
      q.column_names = column_names
      q.sort_criteria = [%w[id asc]]
    end
  end
  let(:column_titles) { column_names.map { |name| column_title(name) } }
  let(:options) { {} }
  let(:export) do
    login_as(user)
    described_class.new(query, options)
  end
  let(:export_pdf) do
    Timecop.freeze(export_time) do
      export.export!
    end
  end
  let(:column_names) { %W[id subject status story_points done_ratio #{link_custom_field.column_name}] }

  def work_packages_sum
    work_package_parent.story_points + work_package_child.story_points
  end

  def work_package_columns(work_package)
    [
      work_package.id.to_s,
      work_package.subject,
      work_package.status.name,
      work_package.story_points.to_s,
      work_package_done_ratio(work_package),
      "https://example.com"
    ]
  end

  def work_package_done_ratio(work_package)
    work_package.done_ratio == 25 ? "25% · Σ 38%" : "50%"
  end

  def work_package_details(work_package, index, ltfs = [])
    result = [
      "#{index}.", work_package.subject,
      column_title(:id), work_package.id.to_s,
      column_title(:status), work_package.status.name,
      column_title(:story_points), work_package.story_points.to_s,
      column_title(:done_ratio), work_package_done_ratio(work_package),
      "My Link", "https://example.com"
    ]
    ltfs.each do |ltf|
      case ltf
      when "description"
        result.push(label_title(:description), work_package.description)
      when text_custom_field_a.id
        result.push(*work_package_details_long_text(text_custom_field_a, work_package))
      when text_custom_field_b.id
        result.push(*work_package_details_long_text(text_custom_field_b, work_package))
      end
    end
    result
  end

  def work_package_details_long_text(field, work_package)
    [field.name, work_package.typed_custom_value_for(field)]
  end

  def cover_page_content
    [project.name, query.name, user.name, export_date_formatted]
  end

  def show
    cmd = "open -a Preview #{export_pdf.content.path}"
    `#{cmd}`
  end

  subject(:pdf_strings) do
    # Joining the results for comparison since word wrapping leads to a different array for the same content
    PDF::Inspector::Text.analyze(File.read(export_pdf.content.path)).strings.join(" ").squeeze(" ")
  end

  def pdf_eq_ignore_spacing(strings)
    expect(pdf.strings.join(" ")).to eq(strings.join(" "))
  end

  context "with a request for a PDF Table" do
    let(:options) { { pdf_export_type: "table" } }

    describe "with default settings" do
      it "contains correct data" do
        expect(pdf_strings).to eq [
          query.name,
          *column_titles,
          *work_package_columns(work_package_parent),
          *work_package_columns(work_package_child),
          "1/1", export_date_formatted, query.name
        ].join(" ")
      end
    end

    describe "grouped" do
      let(:query_attributes) { { group_by: "type" } }

      it "contains correct data" do
        expect(pdf_strings).to eq [
          query.name,
          work_package_parent.type.name,
          *column_titles,
          *work_package_columns(work_package_parent),
          work_package_child.type.name,
          *column_titles,
          *work_package_columns(work_package_child),
          "1/1", export_date_formatted, query.name
        ].join(" ")
      end

      context "when grouped by project phase column (regression #65740)" do
        let(:user) { create(:admin) }
        let!(:project_phase_with_gates) do
          create(:project_phase, :with_gated_definition, project:)
        end
        let!(:project_phase) do
          create(:project_phase, project:)
        end
        let(:query_attributes) { { group_by: "project_phase" } }
        let(:column_names) { %w[id subject project_phase] }

        before do
          work_package_parent.update!(project_phase_definition_id: project_phase_with_gates.definition.id)
          work_package_child.update!(project_phase_definition_id: project_phase.definition.id)
        end

        it "contains correct data" do
          expected_pdf_strings = [
            query.name,

            project_phase_with_gates.name,
            *column_titles - ["Project phase"],
            work_package_parent.id.to_s,
            work_package_parent.subject,

            project_phase.name,
            *column_titles - ["Project phase"],
            work_package_child.id.to_s,
            work_package_child.subject,

            "1/1", export_date_formatted, query.name
          ]

          expect(pdf_strings).to eq(expected_pdf_strings.join(" "))
        end
      end
    end

    describe "grouped with sums" do
      let(:query_attributes) { { group_by: "type", display_sums: true } }

      it "contains correct data" do
        expect(pdf_strings).to eq [
          query.name,
          work_package_parent.type.name,
          *column_titles,
          *work_package_columns(work_package_parent),
          I18n.t("js.label_sum"), work_package_parent.story_points.to_s, "25%",
          work_package_child.type.name,
          *column_titles,
          *work_package_columns(work_package_child),
          I18n.t("js.label_sum"), work_package_child.story_points.to_s, "50%",
          "1/1", export_date_formatted, query.name
        ].join(" ")
      end
    end

    describe "grouped by a custom field with sums" do
      let(:query_attributes) { { group_by: list_custom_field.column_name, display_sums: true } }

      it "contains correct data" do
        expect(pdf_strings).to eq [
          query.name,
          "Foo",
          *column_titles,
          *work_package_columns(work_package_child),
          I18n.t("js.label_sum"), work_package_child.story_points.to_s, "50%",
          "Foo, Bar",
          *column_titles,
          *work_package_columns(work_package_parent),
          I18n.t("js.label_sum"), work_package_parent.story_points.to_s, "25%",
          "1/1", export_date_formatted, query.name
        ].join(" ")
      end
    end
  end

  context "with a request for a PDF Report" do
    let(:options) do
      { pdf_export_type: "report", long_text_fields: "description #{text_custom_field_a.id} #{text_custom_field_b.id}" }
    end
    let(:long_text_fields) { ["description", text_custom_field_a.id, text_custom_field_b.id] }

    describe "with default settings" do
      it "contains correct data" do
        expect(pdf_strings).to eq [
          *cover_page_content,
          query.name,
          "1.", "2", work_package_parent.subject,
          "2.", "2", work_package_child.subject,
          "1/2", export_date_formatted, query.name,
          *work_package_details(work_package_parent, "1", long_text_fields),
          *work_package_details(work_package_child, "2", long_text_fields),
          "2/2", export_date_formatted, query.name
        ].join(" ")
      end
    end

    describe "with no long text fields" do
      let(:options) { { pdf_export_type: "report", long_text_fields: "" } }
      let(:long_text_fields) { [] }

      it "contains correct data" do
        expect(pdf_strings).to eq [
          *cover_page_content,
          query.name,
          "1.", "2", work_package_parent.subject,
          "2.", "2", work_package_child.subject,
          "1/2", export_date_formatted, query.name,
          *work_package_details(work_package_parent, "1", long_text_fields),
          *work_package_details(work_package_child, "2", long_text_fields),
          "2/2", export_date_formatted, query.name
        ].join(" ")
      end
    end

    describe "with reordered long text fields" do
      let(:options) { { pdf_export_type: "report", long_text_fields: "#{text_custom_field_a.id} description" } }
      let(:long_text_fields) { [text_custom_field_a.id, "description"] }

      it "contains correct data" do
        expect(pdf_strings).to eq [
          *cover_page_content,
          query.name,
          "1.", "2", work_package_parent.subject,
          "2.", "2", work_package_child.subject,
          "1/2", export_date_formatted, query.name,
          *work_package_details(work_package_parent, "1", long_text_fields),
          *work_package_details(work_package_child, "2", long_text_fields),
          "2/2", export_date_formatted, query.name
        ].join(" ")
      end
    end

    describe "with hierarchies" do
      let(:query_attributes) { { show_hierarchies: true } }

      it "contains correct data" do
        expect(pdf_strings).to eq [
          *cover_page_content,
          query.name,
          "1.", "2", work_package_parent.subject,
          "1.1.", "2", work_package_child.subject,
          "1/2", export_date_formatted, query.name,
          *work_package_details(work_package_parent, "1", long_text_fields),
          *work_package_details(work_package_child, "1.1", long_text_fields),
          "2/2", export_date_formatted, query.name
        ].join(" ")
      end
    end

    describe "with sums" do
      let(:query_attributes) { { display_sums: true } }

      it "contains correct data" do
        expect(pdf_strings).to eq [
          *cover_page_content,
          query.name,
          "1.", "2", work_package_parent.subject,
          "2.", "2", work_package_child.subject,
          "1/2", export_date_formatted, query.name,
          I18n.t("js.work_packages.tabs.overview"),
          column_title(:story_points),
          column_title(:done_ratio),
          I18n.t("js.label_sum"), work_packages_sum.to_s, "38%",
          *work_package_details(work_package_parent, "1", long_text_fields),
          *work_package_details(work_package_child, "2", long_text_fields),
          "2/2", export_date_formatted, query.name
        ].join(" ")
      end
    end

    describe "grouped" do
      let(:long_text_fields) { [] }
      let(:options) { { pdf_export_type: "report", long_text_fields: "" } }

      describe "by type with sums" do
        let(:query_attributes) { { display_sums: true, group_by: "type" } }

        it "contains correct data" do
          expect(pdf_strings).to eq [
            *cover_page_content,
            query.name,
            "1.", "2", work_package_parent.subject,
            "2.", "2", work_package_child.subject,
            "1/2", export_date_formatted, query.name,
            I18n.t("js.work_packages.tabs.overview"),
            column_title(:type), column_title(:story_points), column_title(:done_ratio),
            work_package_parent.type.name, work_package_parent.story_points.to_s, "25%",
            work_package_child.type.name, work_package_child.story_points.to_s, "50%",
            I18n.t("js.label_sum"), work_packages_sum.to_s, "38%",
            *work_package_details(work_package_parent, "1", long_text_fields),
            *work_package_details(work_package_child, "2", long_text_fields),
            "2/2", export_date_formatted, query.name
          ].join(" ")
        end
      end

      describe "by a custom field with sums" do
        let(:query_attributes) { { display_sums: true, group_by: list_custom_field.column_name } }

        it "contains correct data" do
          expect(pdf_strings).to eq [
            *cover_page_content,
            query.name,
            "1.", "2", work_package_child.subject,
            "2.", "2", work_package_parent.subject,
            "1/2", export_date_formatted, query.name,
            I18n.t("js.work_packages.tabs.overview"),
            list_custom_field.name, column_title(:story_points), column_title(:done_ratio),

            "Foo", work_package_child.story_points.to_s, "50%",
            "Foo, Bar", work_package_parent.story_points.to_s, "25%",
            I18n.t("js.label_sum"), work_packages_sum.to_s, "38%",

            *work_package_details(work_package_child, "1", long_text_fields),
            *work_package_details(work_package_parent, "2", long_text_fields),
            "2/2", export_date_formatted, query.name
          ].join(" ")
        end
      end
    end
  end
end
