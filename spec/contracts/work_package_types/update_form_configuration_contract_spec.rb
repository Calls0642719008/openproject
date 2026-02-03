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

module WorkPackageTypes
  RSpec.describe UpdateFormConfigurationContract do
    let(:user) { create(:admin) }
    let(:model) { create(:type, name: "O-Negative") }

    subject(:contract) { described_class.new(model, user, options: {}) }

    context "without enterprise features enabled" do
      it "the contract is invalid" do
        expect(contract.validate).to be_falsey
      end

      it "adds and error to the contract" do
        contract.validate
        expect(contract.errors.details).to eq(base: [{ action: "Edit Attribute Groups", error: :error_enterprise_only }])
      end
    end

    context "with enterprise features enabled", with_ee: %i[edit_attribute_groups] do
      context "when the user isn't admin" do
        let(:user) { create(:user) }

        it "the contract is invalid" do
          expect(contract.validate).to be_falsey
        end

        it "adds and error to the contract" do
          contract.validate
          expect(contract.errors.details).to eq(base: [{ error: :error_unauthorized }])
        end
      end

      describe "validations" do
        context "when attribute_groups is present and valid" do
          let(:valid_group) { ["foo", ["assignee", "responsible"]] }

          it "is valid" do
            model.attribute_groups = [valid_group]

            expect(contract.validate).to be_truthy
          end
        end

        context "when a group has no name" do
          let(:invalid_group) { ["", ["assignee"]] }

          it "is invalid and adds :group_without_name error" do
            model.attribute_groups = [invalid_group]

            expect(contract.validate).to be_falsey
            expect(contract.errors.details[:attribute_groups]).to include(error: :group_without_name)
          end
        end

        context "when there are duplicate group names" do
          let(:duplicate_group) { ["foo", ["assignee"]] }

          it "is invalid and adds :duplicate_group error" do
            model.attribute_groups = [duplicate_group, duplicate_group]

            expect(contract.validate).to be_falsey
            expect(contract.errors.details[:attribute_groups]).to include(error: :duplicate_group, group: "foo")
          end
        end

        context "when an attribute group contains unknown attributes" do
          let(:invalid_group) { ["foo", ["unknown_attribute"]] }

          it "is invalid and adds an error for the unknown attribute" do
            model.attribute_groups = [invalid_group]

            expect(contract.validate).to be_falsey
            expect(contract.errors.details[:attribute_groups]).to include(
              error: "Invalid work package attribute used: unknown_attribute"
            )
          end
        end

        context "with invalid query group" do
          let(:query) { Query.new(name: "Invalid Query", user:) }
          let(:invalid_query_group) { ["query_group", [query]] }

          it "is invalid and adds an error for the query group" do
            model.attribute_groups = [invalid_query_group]

            expect(contract.validate).to be_falsey
            expect(contract.errors.details[:attribute_groups])
              .to include(hash_including(error: :query_invalid, group: "query_group"))
          end
        end
      end
    end
  end
end
