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
require_module_spec_helper

module Storages
  module Adapters
    module Providers
      module Nextcloud
        module Validators
          RSpec.describe AmpfConfigurationValidator, :webmock do
            let(:storage) { create(:nextcloud_storage_with_local_connection, :as_automatically_managed) }
            let(:project_folder_id) { "1337" }
            let!(:project_storage) do
              create(:project_storage, :as_automatically_managed, project_folder_id:, storage:, project: create(:project))
            end

            let(:files_response) do
              Success(Results::StorageFileCollection.new(
                        files: [StorageFile.new(id: project_folder_id, name: project_storage.managed_project_folder_name)],
                        parent: StorageFile.new(id: "root", name: "root"),
                        ancestors: []
                      ))
            end

            let(:required_versions) do
              YAML.load_file(Rails.root.join("modules/storages/config/nextcloud_dependencies.yml"))&.dig("dependencies")
            end

            let(:capabilities_response) do
              ProviderResults::Capabilities.build(
                app_enabled: true,
                app_version: SemanticVersion.parse(required_versions.dig("integration_app", "min_version")),
                group_folder_enabled: true,
                group_folder_version: SemanticVersion.parse(required_versions.dig("team_folders_app", "min_version"))
              )
            end

            subject(:validator) { described_class.new(storage) }

            before do
              Registry.stub("nextcloud.queries.capabilities", ->(*) { capabilities_response })
              Registry.stub("nextcloud.queries.files", ->(*) { files_response })
            end

            it "pass all checks" do
              expect(validator.call).to be_success
            end

            describe "team_folders_app checks" do
              before do
                Registry.unstub
                Registry.stub("nextcloud.queries.files", ->(*) { files_response })
              end

              it "team_folders_app version mismatch", vcr: "nextcloud/capabilities_success" do
                absurd_version = { dependencies: { team_folders_app: { min_version: "2099.10.138" } } }.deep_stringify_keys
                allow(subject).to receive(:nextcloud_dependencies).and_return(absurd_version)

                results = validator.call
                expect(results[:team_folder_app]).to be_a_failure
                expect(results[:team_folder_app].code).to eq(:nc_dependency_version_mismatch)
                expect(results[:team_folder_app].context[:dependency]).to eq("Team Folders")
              end

              it "integration app disabled / missing", vcr: "nextcloud/capabilities_success_team_folders_disabled" do
                results = validator.call

                expect(results[:team_folder_app]).to be_a_failure
                expect(results[:team_folder_app].code).to eq(:nc_dependency_missing)
                expect(results[:team_folder_app].context[:dependency]).to eq("Team Folders")
              end
            end

            context "if userless authentication fails" do
              let(:files_response) { build_failure(code: :unauthorized, payload: nil) }

              it "fails and skips the next checks" do
                results = validator.call

                states = results.tally
                expect(states).to eq({ success: 2, failure: 1, skipped: 2 })
                expect(results[:userless_access]).to be_failure
                expect(results[:userless_access].code).to eq(:nc_userless_access_denied)
              end
            end

            context "if the files request returns not_found" do
              let(:files_response) { build_failure(code: :not_found, payload: nil) }

              it "fails the check" do
                results = validator.call

                expect(results[:team_folder_presence]).to be_failure
                expect(results[:team_folder_presence].code).to eq(:nc_team_folder_not_found)
              end
            end

            context "if the files request returns an unknown error" do
              let(:files_response) { build_failure(code: :error) }

              before { allow(Rails.logger).to receive(:error) }

              it "fails the check and logs the error" do
                results = validator.call

                expect(results[:files_request]).to be_failure
                expect(results[:files_request].code).to eq(:unknown_error)

                expect(Rails.logger).to have_received(:error).with(/Connection validation failed with unknown error/)
              end
            end

            context "if the files request returns unexpected files" do
              let(:files_response) do
                Success(Results::StorageFileCollection.new(
                          files: [
                            StorageFile.new(id: project_folder_id, name: "I am your father"),
                            StorageFile.new(id: "noooooooooo", name: "testimony_of_luke_skywalker.md")
                          ],
                          parent: StorageFile.new(id: "root", name: "root"),
                          ancestors: []
                        ))
              end

              it "warns the user about extraneous folders" do
                results = validator.call

                expect(results[:team_folder_contents]).to be_a_warning
                expect(results[:team_folder_contents].code).to eq(:nc_unexpected_content)
              end
            end

            private

            def build_failure(code:, payload: nil)
              error = Results::Error.new(code:, payload:, source: self)
              Failure(error)
            end
          end
        end
      end
    end
  end
end
