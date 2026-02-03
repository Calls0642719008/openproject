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

RSpec.shared_examples_for "acts_as_customizable included" do
  describe "#custom_field_changes" do
    context "when no custom field value exists" do
      before do
        model_instance.custom_values.destroy_all
      end

      it "returns no changes" do
        expect(model_instance.custom_field_changes).to be_empty
      end

      context "when a field value is set" do
        before do
          model_instance.custom_values.destroy_all
        end

        it "returns the field changes" do
          model_instance.custom_field_values = { custom_field.id => "test" }
          expect(model_instance.custom_field_changes)
            .to eq({ custom_field.attribute_name => [nil, "test"] })
        end
      end
    end

    context "when a field value is changed from nil" do
      it "returns the field changes" do
        model_instance.custom_field_values = { custom_field.id => "test" }
        expect(model_instance.custom_field_changes)
          .to eq({ custom_field.attribute_name => [nil, "test"] })
      end
    end

    context "when a field value is changed from a string" do
      before do
        model_instance.custom_field_values = { custom_field.id => "test" }
        model_instance.save
      end

      it "returns the field changes" do
        model_instance.custom_field_values = { custom_field.id => "test2" }
        expect(model_instance.custom_field_changes)
          .to eq({ custom_field.attribute_name => ["test", "test2"] })
      end
    end

    context "when a field is set to the same value (unchanged)" do
      before do
        model_instance.custom_field_values = { custom_field.id => "test" }
        model_instance.save
      end

      it "returns no changes" do
        model_instance.custom_field_values = { custom_field.id => "test" }
        expect(model_instance.custom_field_changes).to be_empty
      end
    end

    context "when a field value is changed to nil" do
      before do
        model_instance.custom_field_values = { custom_field.id => "test" }
        model_instance.save
      end

      it "returns the field changes" do
        model_instance.custom_field_values = { custom_field.id => nil }
        expect(model_instance.custom_field_changes)
          .to eq({ custom_field.attribute_name => ["test", nil] })
      end
    end
  end

  context "with a default value" do
    let(:custom_field) { create(:string_wp_custom_field, default_value: "foobar") }

    it "returns no changes" do
      expect(model_instance.custom_field_changes).to be_empty
    end
  end

  context "with a bool custom_field having a default value" do
    let(:custom_field) { create(:boolean_wp_custom_field, default_value: "0") }

    it "returns no changes" do
      expect(model_instance.custom_field_changes).to be_empty
    end
  end

  describe "#custom_values_to_validate" do
    context "for an existing model_instance" do
      subject { model_instance.custom_values_to_validate }

      it "returns an empty array when not explicitly set" do
        expect(subject).to eq([])
      end

      it "returns an empty array set via the setter" do
        model_instance.custom_values_to_validate = []
        expect(subject).to eq([])
      end

      it "returns the values set via the setter" do
        custom_value = model_instance.custom_field_values.first
        model_instance.custom_values_to_validate = custom_value

        expect(subject).to contain_exactly(custom_value)
      end

      it "allows appending values using << operator" do
        custom_value = model_instance.custom_field_values.first

        # Start with empty array
        model_instance.custom_values_to_validate = []
        expect(model_instance.custom_values_to_validate).to eq([])

        # Append using << operator
        model_instance.custom_values_to_validate << custom_value
        expect(model_instance.custom_values_to_validate).to contain_exactly(custom_value)

        # Append another value
        another_value = model_instance.custom_field_values.last
        model_instance.custom_values_to_validate << another_value
        expect(model_instance.custom_values_to_validate).to contain_exactly(custom_value, another_value)
      end

      it "allows appending values using push method" do
        custom_value = model_instance.custom_field_values.first
        another_value = model_instance.custom_field_values.last

        # Start with empty array
        model_instance.custom_values_to_validate = []

        # Append using push method
        model_instance.custom_values_to_validate.push(custom_value, another_value)
        expect(model_instance.custom_values_to_validate).to contain_exactly(custom_value, another_value)
      end
    end

    context "for a new model_instance" do
      subject { new_model_instance.custom_values_to_validate }

      it "returns custom_field_values when not explicitly set" do
        expect(subject).to contain_exactly(
          an_instance_of(CustomValue).and(having_attributes(custom_field_id: custom_field.id))
        )
      end

      it "returns and empty array" do
        new_model_instance.deactivate_custom_field_validations!

        expect(subject).to be_empty
      end

      it "returns the values set via the setter" do
        custom_value = new_model_instance.custom_field_values.first
        new_model_instance.custom_values_to_validate = custom_value

        expect(subject).to contain_exactly(
          an_instance_of(CustomValue).and(having_attributes(custom_field_id: custom_field.id))
        )
      end
    end
  end

  describe "#valid?" do
    shared_examples_for "is valid" do
      it { is_expected.to be_valid(:saving_custom_fields) }
    end

    shared_examples_for "has a validation error on a required custom field" do
      it "is expected to have a validation error" do
        expect(subject).not_to be_valid(:saving_custom_fields)
        expect(subject.errors.symbols_for(custom_field.attribute_getter))
          .to include :blank
      end
    end

    context "with a saved model_instance" do
      subject { model_instance }

      context "with no required custom fields" do
        it_behaves_like "is valid"
      end

      context "with a required custom field" do
        before do
          custom_field.update(is_required: true)
        end

        context "and the custom_values_to_validate is not set" do
          it_behaves_like "is valid"
        end

        context "and the custom_values_to_validate is set to the custom value" do
          before do
            subject.custom_values_to_validate = subject.custom_field_values.first
          end

          it_behaves_like "has a validation error on a required custom field"
        end

        context "and the custom_values_to_validate is set to be empty" do
          before do
            subject.custom_values_to_validate = []
          end

          it_behaves_like "is valid"
        end
      end
    end

    context "with a new_model_instance" do
      subject { new_model_instance }

      context "with no required custom fields" do
        it_behaves_like "is valid"
      end

      context "with a required custom field" do
        before do
          custom_field.update(is_required: true)
        end

        context "and the custom_values_to_validate is not set" do
          it_behaves_like "has a validation error on a required custom field"
        end

        context "and the custom_values_to_validate is set to the custom value" do
          before do
            subject.custom_values_to_validate = subject.custom_field_values.first
          end

          it_behaves_like "has a validation error on a required custom field"
        end

        context "and the custom_values_to_validate is set to be empty" do
          before do
            subject.custom_values_to_validate = []
          end

          it_behaves_like "is valid"
        end
      end
    end
  end
end
