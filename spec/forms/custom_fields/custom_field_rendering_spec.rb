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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe CustomFields::CustomFieldRendering do
  let(:form_class) do
    Class.new do
      include CustomFields::CustomFieldRendering

      attr_reader :model
    end
  end

  let(:form_instance) { form_class.new }
  let(:model) { instance_double(ApplicationRecord) }
  let(:builder) { instance_double(ActionView::Helpers::FormBuilder) }

  before do
    allow(form_instance).to receive(:model).and_return(model)
  end

  describe "#custom_field_input" do
    let(:custom_field) { build(:custom_field, field_format:, multi_value:) }
    let(:form_args) { { custom_field:, object: model } }

    context "for single value custom field" do
      let(:multi_value) { false }

      {
        "string" => CustomFields::Inputs::String,
        "link" => CustomFields::Inputs::String,
        "text" => CustomFields::Inputs::Text,
        "int" => CustomFields::Inputs::Int,
        "float" => CustomFields::Inputs::Float,
        "hierarchy" => CustomFields::Inputs::SingleSelectList,
        "weighted_item_list" => CustomFields::Inputs::SingleSelectList,
        "list" => CustomFields::Inputs::SingleSelectList,
        "date" => CustomFields::Inputs::Date,
        "bool" => CustomFields::Inputs::Bool,
        "user" => CustomFields::Inputs::SingleUserSelectList,
        "version" => CustomFields::Inputs::SingleVersionSelectList,
        "calculated_value" => CustomFields::Inputs::CalculatedValue
      }.each do |format, input_class|
        context "for supported format '#{format}'" do
          let(:input) { instance_double(input_class) }
          let(:field_format) { format }
          let(:extra_args) { { foo: "bar" } }

          before do
            allow(form_instance).to receive(:additional_custom_field_input_arguments).and_return(extra_args)
          end

          it "instantiates #{class_name} with builder and form arguments" do
            allow(input_class).to receive(:new).with(builder, **form_args, **extra_args).and_return(input)
            expect(form_instance.send(:custom_field_input, builder, custom_field)).to eq(input)
          end
        end
      end

      context "for unsupported format" do
        let(:field_format) { "unknown" }

        it "raises an error" do
          expect do
            form_instance.send(:custom_field_input, builder, custom_field)
          end.to raise_error("Unhandled custom field format unknown")
        end
      end
    end

    context "for multi value custom field" do
      let(:multi_value) { true }

      {
        "hierarchy" => CustomFields::Inputs::MultiSelectList,
        "weighted_item_list" => CustomFields::Inputs::MultiSelectList,
        "list" => CustomFields::Inputs::MultiSelectList,
        "user" => CustomFields::Inputs::MultiUserSelectList,
        "version" => CustomFields::Inputs::MultiVersionSelectList
      }.each do |format, input_class|
        context "for supported format '#{format}'" do
          let(:input) { instance_double(input_class) }
          let(:field_format) { format }
          let(:extra_args) { { foo: "bar" } }

          before do
            allow(form_instance).to receive(:additional_custom_field_input_arguments).and_return(extra_args)
          end

          it "instantiates #{class_name} with builder and form arguments" do
            allow(input_class).to receive(:new).with(builder, **form_args, **extra_args).and_return(input)
            expect(form_instance.send(:custom_field_input, builder, custom_field)).to eq(input)
          end
        end
      end

      context "for unsupported format" do
        let(:field_format) { "unknown" }

        it "raises an error" do
          expect do
            form_instance.send(:custom_field_input, builder, custom_field)
          end.to raise_error("Unhandled custom field format unknown")
        end
      end
    end
  end
end
