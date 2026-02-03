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
    module AuthenticationStrategies
      RSpec.describe OAuthUserToken, :webmock do
        let(:user) { create(:user) }
        let(:storage) do
          create(:nextcloud_storage_with_local_connection, :as_not_automatically_managed, oauth_client_token_user: user)
        end
        let(:request_url) { "#{storage.uri}ocs/v1.php/cloud/user" }
        let(:http_options) { { headers: { "OCS-APIRequest" => "true", "Accept" => "application/json" } } }
        let(:strategy_data) { Input::Strategy.build(user:, key: :oauth_user_token) }

        subject(:Authentication) { described_class }

        shared_examples_for "successful response" do |refreshed: false|
          it "must #{'refresh token and ' if refreshed}return success" do
            result = Authentication[strategy_data].call(storage:) { |http| make_request(http) }
            expect(result).to be_success
            expect(result.value!).to eq("EXPECTED_RESULT")
          end
        end

        context "with incomplete storage configuration (missing oauth client)" do
          let(:storage) { create(:nextcloud_storage) }

          it "must return error" do
            result = Authentication[strategy_data].call(storage:) { |http| make_request(http) }
            expect(result).to be_failure

            error = result.failure
            expect(error.code).to eq(:missing_oauth_client)
            expect(error.source).to be(described_class)
          end
        end

        context "with not existent oauth token" do
          let(:user_without_token) { create(:user) }
          let(:strategy_data) { Input::Strategy.build(user: user_without_token, key: :oauth_user_token) }

          it "must return unauthorized" do
            result = Authentication[strategy_data].call(storage:, http_options:) { |http| make_request(http) }
            expect(result).to be_failure

            error = result.failure
            expect(error.code).to eq(:missing_token)
            expect(error.source).to be(described_class)
          end
        end

        context "with invalid oauth refresh token", vcr: "auth/nextcloud/user_token_refresh_token_invalid" do
          before { storage }

          it "must return unauthorized" do
            result = Authentication[strategy_data].call(storage:, http_options:) { |http| make_request(http) }
            expect(result).to be_failure

            error = result.failure
            expect(error.code).to eq(:unauthorized)
            expect(error.source).to be(described_class)
          end

          it "logs, retries once, raises exception if race condition happens" do
            token = OAuthClientToken.last
            strategy = Authentication[strategy_data]

            allow(Rails.logger).to receive(:error)
            allow(strategy).to receive(:current_token).and_return(Success(token))
            allow(token).to receive(:destroy).and_raise(ActiveRecord::StaleObjectError).twice

            expect do
              strategy.call(storage:, http_options:) { |http| make_request(http) }
            end.to raise_error(ActiveRecord::StaleObjectError)

            expect(Rails.logger).to have_received(:error).with(/User ##{user.id} #{user.name}/).once
          end
        end

        context "with invalid oauth access token" do
          it "must refresh token and return success" do
            storage
            token = OAuthClientToken.last
            user_request_stub_1 = stub_request(:get, "https://nextcloud.local/ocs/v1.php/cloud/user")
              .with(
                headers: {
                  "Accept" => "*/*",
                  "Accept-Encoding" => "gzip, deflate",
                  "Authorization" => "Bearer #{token.access_token}",
                  "User-Agent" => /OpenProject \d+\.\d+\.\d+ HTTPX Client/
                }
              )
              .to_return(status: 401, body: <<~XML, headers: {})
                <?xml version="1.0"?>
                <ocs>
                <meta>
                  <status>failure</status>
                  <statuscode>997</statuscode>
                  <message>Current user is not logged in</message>
                  <totalitems></totalitems>
                  <itemsperpage></itemsperpage>
                </meta>
                <data/>
                </ocs>
              XML
            user_request_stub_2 = stub_request(:get, "https://nextcloud.local/ocs/v1.php/cloud/user")
              .with(
                headers: {
                  "Accept" => "*/*",
                  "Accept-Encoding" => "gzip, deflate",
                  "Authorization" => "Bearer NEW_ACCESS_TOKEN",
                  "User-Agent" => /OpenProject \d+\.\d+\.\d+ HTTPX Client/
                }
              )
              .to_return(status: 200, body: <<~JSON, headers: { "Content-Type" => "application/json; charset=utf-8" })
                {"ocs":{"meta":{"status":"ok","statuscode":100,"message":"OK","totalitems":"","itemsperpage":""},"data":{"enabled":true,"storageLocation":"/var/www/html/data/admin","id":"admin","lastLogin":1709888213000,"backend":"Database","subadmin":[],"quota":{"free":962269761536,"used":1137306515,"total":963407068051,"relative":0.12,"quota":-3},"manager":"","avatarScope":"v2-federated","email":null,"emailScope":"v2-federated","additional_mail":[],"additional_mailScope":[],"displayname":"admin","display-name":"admin","displaynameScope":"v2-federated","phone":"","phoneScope":"v2-local","address":"","addressScope":"v2-local","website":"","websiteScope":"v2-local","twitter":"","twitterScope":"v2-local","fediverse":"","fediverseScope":"v2-local","organisation":"","organisationScope":"v2-local","role":"","roleScope":"v2-local","headline":"","headlineScope":"v2-local","biography":"","biographyScope":"v2-local","profile_enabled":"1","profile_enabledScope":"v2-local","groups":["admin"],"language":"en","locale":"","notify_email":null,"backendCapabilities":{"setDisplayName":true,"setPassword":true}}}}
              JSON
            token_request_stub = stub_request(:post, "https://nextcloud.local/index.php/apps/oauth2/api/v1/token")
              .with(
                body: { "client_id" => token.oauth_client.client_id,
                        "client_secret" => token.oauth_client.client_secret,
                        "grant_type" => "refresh_token",
                        "refresh_token" => token.refresh_token,
                        "scope" => "" },
                headers: {
                  "Accept" => "*/*",
                  "Accept-Encoding" => "gzip, deflate",
                  "Content-Type" => "application/x-www-form-urlencoded",
                  "User-Agent" => /OpenProject \d+\.\d+\.\d+ HTTPX Client/
                }
              )
              .to_return(status: 200, body: <<~JSON, headers: { "Content-Type" => "application/json; charset=utf-8" })
                {"access_token":"NEW_ACCESS_TOKEN","token_type":"Bearer","expires_in":3600,"refresh_token":"NEW_REFRESH_TOKEN","user_id":"admin"}
              JSON
            result = Authentication[strategy_data].call(storage:) { |http| make_request(http) }

            expect(user_request_stub_1).to have_been_made.once
            expect(user_request_stub_2).to have_been_made.once
            expect(token_request_stub).to have_been_made.once

            expect(result).to be_success
            expect(result.value!).to eq("EXPECTED_RESULT")
          end
        end

        context "with valid access token", vcr: "auth/one_drive/user_token" do
          let(:request_url) { "#{storage.uri}v1.0/me" }
          let(:storage) { create(:one_drive_sandbox_storage, oauth_client_token_user: user) }

          it_behaves_like "successful response"
        end

        private

        def make_request(http) = handle_response(http.get(request_url))

        def handle_response(response)
          case response
          in { status: 200..299 }
            Success("EXPECTED_RESULT")
          in { status: 401 }
            error(:unauthorized)
          in { status: 403 }
            error(:forbidden)
          in { status: 404 }
            error(:not_found)
          else
            error(:error)
          end
        end

        def error(code)
          Failure(Results::Error.new(source: "EXECUTING_QUERY", code:))
        end
      end
    end
  end
end
