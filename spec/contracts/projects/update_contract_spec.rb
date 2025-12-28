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
require_relative "shared_contract_examples"

RSpec.describe Projects::UpdateContract do
  it_behaves_like "project contract" do
    shared_let(:custom_field) { create(:integer_project_custom_field) }
    shared_let(:admin_only_custom_field) { create(:integer_project_custom_field, admin_only: true) }
    shared_let(:not_enabled_custom_field) { create(:integer_project_custom_field) }

    let(:project) do
      build_stubbed(:project,
                    active: project_active,
                    public: project_public,
                    status_code: project_status_code,
                    status_explanation: project_status_explanation,
                    workspace_type: project_workspace_type).tap do |p|
        # Use real AR relations for the custom field associations with actual IDs
        available_custom_fields = ProjectCustomField.where(id: [custom_field, admin_only_custom_field])
        all_available_custom_fields = ProjectCustomField.where(id: [custom_field, admin_only_custom_field,
                                                                    not_enabled_custom_field])

        allow(p).to receive_messages(available_custom_fields:, all_available_custom_fields:)

        next unless project_changed

        # in order to actually have something changed
        p.name = project_name
        p.parent = project_parent
        p.identifier = project_identifier
        p.templated = project_templated
      end
    end
    let(:project_permissions) { %i(edit_project) }
    let(:project_changed) { true }
    let(:options) { {} }

    subject(:contract) { described_class.new(project, current_user, options:) }

    context "if the identifier is nil" do
      let(:project_identifier) { nil }

      it_behaves_like "contract is invalid", identifier: %i(blank)
    end

    context "if workspace_type is changed" do
      before do
        project.workspace_type = "portfolio"
      end

      it_behaves_like "contract is invalid", workspace_type: :error_readonly
    end

    context "if template is changed" do
      before do
        project.template_id = 1
      end

      it_behaves_like "contract is invalid", template_id: :error_readonly
    end

    describe "permissions" do
      context "with edit_project_attributes" do
        let(:project_permissions) { %i(edit_project_attributes) }

        context "when project_attributes_only flag is true" do
          let(:options) { { project_attributes_only: true } }

          before do
            project.custom_field_values = { custom_field.id => "1" }
          end

          context "and only project_custom_fields are changed" do
            let(:project_changed) { false }

            it_behaves_like "contract is valid"
          end

          context "and other project attributes are changed too" do
            let(:project_changed) { true }

            it_behaves_like "contract is invalid",
                            name: %i(error_readonly),
                            parent_id: %i(error_readonly),
                            identifier: %i(error_readonly)
          end
        end

        context "when project_attributes_only flag is false" do
          let(:options) { { project_attributes_only: false } }

          it_behaves_like "contract is invalid", name: %i(error_readonly)
        end
      end

      context "with edit_project" do
        context "when project_attributes_only flag is true" do
          let(:options) { { project_attributes_only: true } }

          it_behaves_like "contract user is unauthorized"
        end

        context "when project_attributes_only flag is false" do
          let(:options) { { project_attributes_only: false } }

          context "and only project attributes are changed" do
            let(:project_changed) { true }

            it_behaves_like "contract is valid"
          end

          context "and project_custom_fields are changed too" do
            let(:project_changed) { true }

            before do
              project.custom_field_values = { custom_field.id => "1" }
            end

            it "is invalid" do
              expect_contract_invalid("custom_field_#{custom_field.id}": %i(error_readonly))
            end
          end
        end
      end

      context "with both edit_project and edit_project_attributes are set" do
        let(:project_permissions) { %i(edit_project edit_project_attributes) }

        context "when project_attributes_only flag is true" do
          let(:options) { { project_attributes_only: true } }

          context "and only project attributes are changed" do
            let(:project_changed) { true }

            it_behaves_like "contract is invalid",
                            name: %i(error_readonly),
                            parent_id: %i(error_readonly),
                            identifier: %i(error_readonly)
          end

          context "and only project_custom_fields are changed" do
            let(:project_changed) { false }

            before do
              project.custom_field_values = { custom_field.id => "1" }
            end

            it_behaves_like "contract is valid"
          end

          context "when both project attributes and project custom_fields are changed" do
            let(:project_changed) { true }

            before do
              project.custom_field_values = { custom_field.id => "1" }
            end

            it_behaves_like "contract is invalid",
                            name: %i(error_readonly),
                            parent_id: %i(error_readonly),
                            identifier: %i(error_readonly)
          end
        end

        context "when project_attributes_only flag is false" do
          let(:options) { { project_attributes_only: false } }

          context "and only project attributes are changed" do
            let(:project_changed) { true }

            it_behaves_like "contract is valid"
          end

          context "and project_custom_fields are changed too" do
            let(:project_changed) { true }

            before do
              project.custom_field_values = { custom_field.id => "1" }
            end

            it_behaves_like "contract is valid"
          end
        end
      end

      context "without permissions when project_attributes_only flag is true" do
        let(:project_permissions) { [] }
        let(:options) { { project_attributes_only: true } }

        it_behaves_like "contract user is unauthorized"
      end
    end

    describe "#writable_attributes" do
      let(:project_changed) { false }

      shared_examples "can write" do |attribute|
        it "can write #{attribute}" do
          attr_name = if respond_to?(attribute)
                        "custom_field_#{send(attribute).id}"
                      else
                        attribute.to_s
                      end
          expect(contract.writable_attributes).to include(attr_name)
        end
      end

      shared_examples "can not write" do |attribute|
        it "can not write #{attribute}" do
          attr_name = if respond_to?(attribute)
                        "custom_field_#{send(attribute).id}"
                      else
                        attribute.to_s
                      end
          expect(contract.writable_attributes).not_to include(attr_name)
        end
      end

      context "with edit_project_attributes" do
        let(:project_permissions) { %i(edit_project_attributes) }

        context "when project_attributes_only flag is true" do
          let(:options) { { project_attributes_only: true } }

          it_behaves_like "can write", :custom_field
          it_behaves_like "can not write", :name
        end

        context "when project_attributes_only flag is false" do
          let(:options) { { project_attributes_only: false } }

          it_behaves_like "can write", :custom_field
          it_behaves_like "can not write", :name
        end
      end

      context "with edit_project" do
        context "when project_attributes_only flag is true" do
          let(:options) { { project_attributes_only: true } }

          it_behaves_like "can not write", :custom_field
          it_behaves_like "can not write", :name
        end

        context "when project_attributes_only flag is false" do
          let(:options) { { project_attributes_only: false } }

          it_behaves_like "can not write", :custom_field
          it_behaves_like "can write", :name
        end
      end

      context "with both edit_project and edit_project_attributes are set" do
        let(:project_permissions) { %i(edit_project edit_project_attributes) }

        context "when project_attributes_only flag is true" do
          let(:options) { { project_attributes_only: true } }

          it_behaves_like "can write", :custom_field
          it_behaves_like "can not write", :name
        end

        context "when project_attributes_only flag is false" do
          let(:options) { { project_attributes_only: false } }

          it_behaves_like "can write", :custom_field
          it_behaves_like "can write", :name
        end
      end

      context "without permissions" do
        let(:project_permissions) { [] }

        context "when project_attributes_only flag is true" do
          let(:options) { { project_attributes_only: true } }

          it_behaves_like "can not write", :custom_field
          it_behaves_like "can not write", :name
        end

        context "when project_attributes_only flag is false" do
          let(:options) { { project_attributes_only: false } }

          it_behaves_like "can not write", :custom_field
          it_behaves_like "can not write", :name
        end
      end

      context "with admin-only custom fields" do
        shared_examples "admin-only custom field behavior" do
          context "when user is admin" do
            let(:current_user) { build_stubbed(:admin) }

            it_behaves_like "can write", :admin_only_custom_field
          end

          context "when user is not admin" do
            let(:current_user) { build_stubbed(:user) }
            let(:project_permissions) { %i(edit_project_attributes) }

            it_behaves_like "can not write", :admin_only_custom_field

            context "with all permissions" do
              let(:project_permissions) { %i(edit_project edit_project_attributes) }

              it_behaves_like "can not write", :admin_only_custom_field
            end
          end
        end

        context "when project_attributes_only is true" do
          let(:options) { { project_attributes_only: true } }

          it_behaves_like "admin-only custom field behavior"
        end

        context "when project_attributes_only is false" do
          let(:options) { { project_attributes_only: false } }

          it_behaves_like "admin-only custom field behavior"
        end
      end

      context "with not enabled custom fields" do
        context "when project_attributes_only is true" do
          let(:options) { { project_attributes_only: true } }

          context "when user is admin" do
            let(:current_user) { build_stubbed(:admin) }
            let(:project_permissions) { %i(edit_project_attributes) }

            it_behaves_like "can not write", :not_enabled_custom_field
          end

          context "when user is not admin" do
            let(:current_user) { build_stubbed(:user) }
            let(:project_permissions) { %i(edit_project_attributes) }

            it_behaves_like "can not write", :not_enabled_custom_field

            context "with all permissions" do
              let(:project_permissions) { %i(edit_project edit_project_attributes) }

              it_behaves_like "can not write", :not_enabled_custom_field
            end
          end
        end

        context "when project_attributes_only is false (for API backward compatibility)" do
          let(:options) { { project_attributes_only: false } }

          context "when user is admin" do
            let(:current_user) { build_stubbed(:admin) }
            let(:project_permissions) { %i(edit_project edit_project_attributes) }

            it_behaves_like "can write", :not_enabled_custom_field
          end

          context "when user is not admin" do
            let(:current_user) { build_stubbed(:user) }
            let(:project_permissions) { %i(edit_project_attributes) }

            it_behaves_like "can not write", :not_enabled_custom_field

            context "with all permissions" do
              let(:project_permissions) { %i(edit_project edit_project_attributes) }

              it_behaves_like "can write", :not_enabled_custom_field
            end
          end
        end
      end
    end
  end
end
