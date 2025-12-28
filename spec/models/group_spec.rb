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
require_relative "../support/shared/become_member"

RSpec.describe Group do
  let(:group) { create(:group) }
  let(:new_group) { described_class.new(lastname: "New group") }
  let(:user) { create(:user) }
  let(:watcher) { create(:user) }
  let(:project) { create(:project_with_types) }
  let(:status) { create(:status) }
  let(:package) do
    build(:work_package, type: project.types.first,
                         author: user,
                         project:,
                         status:)
  end

  it "creates" do
    expect(new_group.save).to be true
  end

  describe "with long but allowed attributes" do
    it "is valid" do
      group.name = "a" * 256
      expect(group).to be_valid
      expect(group.save).to be_truthy
    end
  end

  describe "with a name too long" do
    it "is invalid" do
      group.name = "a" * 257
      expect(group).not_to be_valid
      expect(group.save).to be_falsey
    end
  end

  describe "a user with and overly long firstname (> 256 chars)" do
    it "is invalid" do
      user.firstname = "a" * 257
      expect(user).not_to be_valid
      expect(user.save).to be_falsey
    end
  end

  describe "#group_users" do
    context "when adding a user" do
      context "if it does not exist" do
        it "does not create a group user" do
          count = group.group_users.count
          gu = group.group_users.create user_id: User.maximum(:id).to_i + 1

          expect(gu).not_to be_valid
          expect(group.group_users.count).to eq count
        end
      end

      it "updates the timestamp" do
        updated_at = group.updated_at
        group.group_users.create(user:)

        expect(updated_at < group.reload.updated_at)
          .to be_truthy
      end
    end

    context "when removing a user" do
      it "updates the timestamp" do
        group.group_users.create(user:)
        updated_at = group.reload.updated_at

        group.group_users.destroy_all

        expect(updated_at < group.reload.updated_at)
          .to be_truthy
      end
    end
  end

  describe "#create" do
    describe "group with empty group name" do
      let(:group) { build(:group, lastname: "") }

      it { expect(group).not_to be_valid }

      describe "error message" do
        before do
          group.valid?
        end

        it { expect(group.errors.full_messages[0]).to include I18n.t("attributes.name") }
      end
    end
  end

  describe "preference" do
    %w{preference
       preference=
       build_preference
       create_preference
       create_preference!}.each do |method|
      it "does not respond to #{method}" do
        expect(group).not_to respond_to method
      end
    end
  end

  describe "#name" do
    it { expect(group).to validate_presence_of :name }
    it { expect(group).to validate_uniqueness_of :name }
  end

  describe ".containing_user" do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:group1) { create(:group) }
    let(:group2) { create(:group) }
    let(:group3) { create(:group) }

    before do
      # Add user1 to group1 and group2
      group1.group_users.create(user: user1)
      group2.group_users.create(user: user1)

      # Add user2 to group2 and group3
      group2.group_users.create(user: user2)
      group3.group_users.create(user: user2)
    end

    it "returns groups that contain the given user" do
      groups_for_user1 = described_class.containing_user(user1)
      expect(groups_for_user1).to contain_exactly(group1, group2)

      groups_for_user2 = described_class.containing_user(user2)
      expect(groups_for_user2).to contain_exactly(group2, group3)
    end

    it "returns empty collection when user is not in any groups" do
      user_without_groups = create(:user)
      expect(described_class.containing_user(user_without_groups)).to be_empty
    end

    it "defaults to current user when no user is provided" do
      User.current = user1
      expect(described_class.containing_user).to contain_exactly(group1, group2)
    end
  end

  describe ".visible" do
    context "when called on an association (user.groups.visible)" do
      let(:target_user) { create(:user) }
      let(:viewer) { create(:user) }
      let(:shared_group) { create(:group) }
      let(:other_group) { create(:group) }

      before do
        # target_user is in both groups
        shared_group.group_users.create(user: target_user)
        other_group.group_users.create(user: target_user)

        # viewer is only in shared_group
        shared_group.group_users.create(user: viewer)
      end

      it "returns only the groups the viewer can see from the user's groups" do
        # target_user.groups returns [shared_group, other_group]
        # viewer can see shared_group (same group) but not other_group
        visible_groups = target_user.groups.visible(viewer)

        expect(visible_groups).to contain_exactly(shared_group)
        expect(visible_groups).not_to include(other_group)
      end
    end
  end

  it_behaves_like "creates an audit trail on destroy" do
    subject { create(:attachment) }
  end

  it_behaves_like "acts_as_customizable included" do
    let!(:model_instance) { group }
    let!(:new_model_instance) { new_group }
    let!(:custom_field) { create(:group_custom_field, :string, is_required: false) }
  end
end
