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

require "rails_helper"

RSpec.describe Users::HoverCardComponent, type: :component do
  include Rails.application.routes.url_helpers

  shared_let(:project) { create(:project) }
  let(:user) { create(:user, firstname: "in my project", member_with_permissions: { project => [:view_project] }) }
  let(:current_user) { create(:user, member_with_permissions: { project => [:manage_members] }) }

  let(:groups) { [] }

  subject { described_class.new(id: user.id) }

  before do
    groups
    login_as(current_user)
    render_inline(subject)
  end

  context "when user is not visible" do
    let(:user) { create(:user, firstname: "not visible") }

    it "renders nothing" do
      expect(rendered_content).to eq ""
    end
  end

  it "renders successfully" do
    find_test_selector("user-hover-card-name", text: user.name)
  end

  context "when the user does not exist" do
    let(:user) { instance_double(User, id: 9000) }

    it "renders nothing" do
      expect(rendered_content).to eq ""
    end
  end

  context "when displaying email addresses" do
    it "hides the email address of a user" do
      expect(page).not_to have_test_selector("user-hover-card-email")
    end

    context "with the rights to view email addresses" do
      # Admin is allowed to see emails
      let(:current_user) { build(:admin) }

      it "shows the email address of a user" do
        find_test_selector("user-hover-card-email", text: user.mail)
      end
    end
  end

  context "when showing the group summary" do
    it "shows a no results text for users without group memberships" do
      g = find_test_selector("user-hover-card-groups")
      expect(g).to have_text(I18n.t("users.groups.no_results_title_text"))
    end

    context "with the user being member of some groups" do
      let(:groups) do
        Array.new(2) { create(:group, members: user) }
      end

      context "and the current being a member in the group" do
        let(:groups) do
          [
            create(:group, members: [current_user, user], lastname: "Group with current user"),
            create(:group, members: user)
          ]
        end

        it "lists the one group" do
          g = find_test_selector("user-hover-card-groups")

          expect(g).to have_text("Member of Group with current user.")
        end
      end

      context "and the current user seeing all groups" do
        let(:current_user) { create(:user, global_permissions: %i[view_all_principals]) }

        it "lists the group names for a user" do
          g = find_test_selector("user-hover-card-groups")

          expect(g).to have_text("Member of #{groups.first.lastname}, #{groups.last.lastname}.")
        end
      end

      context "with no rights to manage members" do
        # No manage_members permission:
        let(:another_user) { create(:user) }

        it "does not show groups" do
          g = find_test_selector("user-hover-card-groups")

          expect(g).to have_text(I18n.t("users.groups.no_results_title_text"))
        end
      end
    end

    context "with the user being member of many groups and seeing them" do
      let(:current_user) { create(:user, global_permissions: %i[view_all_principals]) }

      let!(:groups) do
        ("A".."H").map { |char| create(:group, lastname: "Group #{char}", members: user) }
      end

      it "lists some group names with truncation" do
        g = find_test_selector("user-hover-card-groups")

        expect(g).to have_text("Member of #{groups.slice(0, 4).map(&:lastname).join(', ')} and 4 more.")
      end
    end
  end

  context "when clicking on the Open Profile button" do
    it "leads to the users profile" do
      b = find_test_selector("user-hover-card-profile-btn")

      expect(b).to have_text(I18n.t("users.open_profile"))
      expect(b["href"]).to eq(user_path(user))
    end

    context "with the right to manage users" do
      let(:current_user) { build(:admin) }

      it "leads to editing the users profile" do
        b = find_test_selector("user-hover-card-profile-btn")

        expect(b).to have_text(I18n.t("users.open_profile"))
        expect(b["href"]).to eq(edit_user_path(user))
      end
    end
  end
end
