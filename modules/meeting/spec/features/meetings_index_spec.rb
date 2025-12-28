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

require_relative "../support/pages/meetings/index"

RSpec.describe "Meetings", "Index", :js do
  # The order the Projects are created in is important. By naming `project` alphanumerically
  # after `other_project`, we can ensure that subsequent specs that assert sorting is
  # correct for the right reasons (sorting by Project name and not id)
  shared_let(:project) { create(:project, name: "Project 2", enabled_module_names: %w[meetings]) }
  shared_let(:other_project) { create(:project, name: "Project 1", enabled_module_names: %w[meetings]) }
  let(:role) { create(:project_role, permissions:) }
  let(:permissions) { %i(view_meetings) }
  let(:user) do
    create(:user) do |user|
      [project, other_project].each do |p|
        create(:member,
               project: p,
               principal: user,
               roles: [role])
      end
    end
  end

  shared_let(:meeting) do
    create(:meeting,
           :author_participates,
           project:,
           title: "Awesome meeting today!",
           start_time: Time.current)
  end
  shared_let(:tomorrows_meeting) do
    create(:meeting,
           :author_participates,
           project:,
           title: "Awesome meeting tomorrow!",
           start_time: 1.day.from_now,
           duration: 2.0,
           location: "no-protocol.com")
  end
  shared_let(:meeting_with_no_location) do
    create(:meeting,
           :author_participates,
           project:,
           title: "Boring meeting without a location!",
           start_time: 1.day.from_now,
           location: "")
  end
  shared_let(:meeting_with_malicious_location) do
    create(:meeting,
           :author_participates,
           project:,
           title: "Sneaky meeting!",
           start_time: 1.day.from_now,
           location: "<script>alert('Description');</script>")
  end
  shared_let(:yesterdays_meeting) do
    create(:meeting,
           :author_participates,
           project:,
           title: "Awesome meeting yesterday!",
           start_time: 1.day.ago)
  end

  shared_let(:other_project_meeting) do
    create(:meeting,
           :author_participates,
           project: other_project,
           title: "Awesome other project meeting!",
           start_time: 2.days.from_now,
           duration: 2.0,
           location: "not-a-url")
  end
  shared_let(:ongoing_meeting) do
    create(:meeting,
           :author_participates,
           project:,
           title: "Awesome ongoing meeting!",
           start_time: 30.minutes.ago)
  end

  def setup_meeting_involvement
    invite_to_meeting(tomorrows_meeting)
    invite_to_meeting(yesterdays_meeting)
    create(:meeting_participant, :attendee, user:, meeting: yesterdays_meeting)
    create(:meeting_participant, :attendee, user:, meeting: tomorrows_meeting)
    meeting.update!(author: user)
  end

  def invite_to_meeting(meeting)
    create(:meeting_participant, :invitee, user:, meeting:)
  end

  before do
    login_as user
  end

  shared_examples "sidebar filtering" do |context:|
    context "when showing all meetings without invitations" do
      it "does not show under My meetings, but in All meetings" do
        meetings_page.visit!
        meetings_page.expect_no_meetings_listed
        meetings_page.expect_blank_slate_component

        meetings_page.set_sidebar_filter "All meetings"

        # It now includes the ongoing meeting I'm not invited to
        if context == :global
          [ongoing_meeting, meeting, tomorrows_meeting, other_project_meeting]
        else
          [ongoing_meeting, meeting, tomorrows_meeting]
        end
      end
    end

    context "when showing all meetings with the sidebar" do
      before do
        ongoing_meeting
        other_project_meeting
        setup_meeting_involvement
        meetings_page.visit!
        meetings_page.set_sidebar_filter "All meetings"
      end

      context 'with the "Upcoming meetings" quick filter' do
        before do
          meetings_page.set_quick_filter upcoming: true
        end

        it "shows all upcoming and ongoing meetings", :aggregate_failures do
          expected_upcoming_meetings =
            if context == :global
              [ongoing_meeting, meeting, tomorrows_meeting, meeting_with_no_location,
               meeting_with_malicious_location, other_project_meeting]
            else
              [ongoing_meeting, meeting, tomorrows_meeting, meeting_with_no_location, meeting_with_malicious_location]
            end

          meetings_page.expect_meetings_listed_in_order(*expected_upcoming_meetings)
          meetings_page.expect_meetings_not_listed(yesterdays_meeting)
        end
      end

      context 'with the "Past meetings" quick filter' do
        before do
          meetings_page.set_quick_filter upcoming: false
        end

        it "show all past meetings" do
          meetings_page.expect_meetings_listed_in_table(yesterdays_meeting, meeting, ongoing_meeting)
          meetings_page.expect_meetings_not_listed(tomorrows_meeting)

          # keeps the past filter selected when changing advanced filters (Regression #61875)" do
          meetings_page.open_filters
          meetings_page.remove_filter "invited_user_id"
          click_on "Apply"

          wait_for_network_idle

          if context == :global
            expect(page).to have_current_path(meetings_path(upcoming: false, filters: "[]"))
          else
            expect(page).to have_current_path(project_meetings_path(project, upcoming: false, filters: "[]"))
          end
        end
      end

      context 'with the "Invitations" filter' do
        before do
          meetings_page.set_sidebar_filter "Invitations"
        end

        it "shows all meetings I've been marked as invited to with a quick filter" do
          meetings_page.expect_meeting_listed_in_group(tomorrows_meeting, key: :tomorrow)
          meetings_page.expect_meetings_not_listed(yesterdays_meeting,
                                                   meeting,
                                                   ongoing_meeting)

          meetings_page.set_quick_filter upcoming: false

          meetings_page.expect_meetings_listed_in_table(yesterdays_meeting)

          meetings_page.expect_meetings_not_listed(meeting, tomorrows_meeting)
        end
      end

      context 'with the "Attendee" filter' do
        before do
          meetings_page.set_sidebar_filter "Attended"
        end

        it "shows all past meetings I've been marked as attending to" do
          meetings_page.expect_meetings_listed(yesterdays_meeting)
          meetings_page.expect_meetings_not_listed(meeting,
                                                   ongoing_meeting,
                                                   tomorrows_meeting)

          # Switch to upcoming
          meetings_page.set_quick_filter upcoming: true

          meetings_page.expect_meetings_listed(tomorrows_meeting)
          meetings_page.expect_meetings_not_listed(yesterdays_meeting,
                                                   meeting,
                                                   ongoing_meeting)
        end
      end

      context 'with the "Creator" filter' do
        before do
          meetings_page.set_sidebar_filter "Created by me"
        end

        it "shows all meetings I'm the author of" do
          meetings_page.expect_meetings_listed(meeting)
          meetings_page.expect_meetings_not_listed(yesterdays_meeting,
                                                   ongoing_meeting,
                                                   tomorrows_meeting)
        end
      end
    end
  end

  context "when visiting from a global context" do
    let(:meetings_page) { Pages::Meetings::Index.new(project: nil) }

    it "lists all upcoming meetings for all projects the user is invited to" do
      invite_to_meeting(meeting)
      invite_to_meeting(yesterdays_meeting)
      invite_to_meeting(other_project_meeting)

      meetings_page.visit!
      meetings_page.expect_meeting_listed_in_group(meeting, key: :today)
      meetings_page.expect_meeting_listed_in_group(other_project_meeting)
      meetings_page.expect_meetings_not_listed(yesterdays_meeting)
    end

    it "renders a link to each meeting's location if present and a valid URL" do
      invite_to_meeting(meeting)
      invite_to_meeting(meeting_with_no_location)
      invite_to_meeting(meeting_with_malicious_location)
      invite_to_meeting(tomorrows_meeting)
      invite_to_meeting(other_project_meeting)

      meetings_page.visit!

      meetings_page.expect_link_to_meeting_location(meeting)
      meetings_page.expect_plaintext_meeting_location(tomorrows_meeting)
      meetings_page.expect_plaintext_meeting_location(other_project_meeting)
      meetings_page.expect_plaintext_meeting_location(meeting_with_malicious_location)
      meetings_page.expect_no_meeting_location(meeting_with_no_location)
    end

    context "and the user is only allowed to view meetings" do
      let(:permissions) { %i[view_meetings] }

      it "doesn't show a create new button" do
        meetings_page.visit!

        meetings_page.expect_no_create_new_button
      end

      it "shows a download ical event action button for each meeting" do
        invite_to_meeting(meeting)
        meetings_page.visit!

        meetings_page.expect_ical_action(meeting)
      end

      it "doesn't show a copy meeting action button for each meeting" do
        invite_to_meeting(meeting)
        meetings_page.visit!

        meetings_page.expect_no_copy_action(meeting)
      end

      it "doesn't show a delete meeting action button for each meeting" do
        invite_to_meeting(meeting)
        meetings_page.visit!

        meetings_page.expect_no_delete_action(meeting)
      end
    end

    context "and the user is allowed to create meetings" do
      let(:permissions) { %i(view_meetings create_meetings) }

      it "shows the create new button" do
        meetings_page.visit!

        meetings_page.expect_create_new_button
      end

      it "allows creation of both types of meetings" do
        meetings_page.visit!

        meetings_page.expect_create_new_types
      end

      it "shows a copy meeting action button for each meeting" do
        invite_to_meeting(meeting)
        meetings_page.visit!

        meetings_page.expect_copy_action(meeting)
      end
    end

    context "and the user is allowed to delete meetings" do
      let(:permissions) { %i(view_meetings delete_meetings) }

      it "shows a delete meeting action button for each meeting" do
        invite_to_meeting(meeting)
        meetings_page.visit!

        meetings_page.expect_delete_action(meeting)
      end
    end

    include_examples "sidebar filtering", context: :global
  end

  context "when visiting from a project specific context" do
    let(:meetings_page) { Pages::Meetings::Index.new(project:) }

    context "via the menu" do
      specify "with no meetings" do
        meetings_page.navigate_by_project_menu

        meetings_page.expect_no_meetings_listed
        meetings_page.expect_blank_slate_component
      end
    end

    context "when the user is allowed to create meetings" do
      let(:permissions) { %i(view_meetings create_meetings) }

      it "shows the create new button" do
        meetings_page.visit!
        meetings_page.expect_create_new_button
      end
    end

    context "when the user is not allowed to create meetings" do
      let(:permissions) { %i[view_meetings] }

      it "doesn't show the create new button" do
        meetings_page.visit!
        meetings_page.expect_no_create_new_button
      end
    end

    include_examples "sidebar filtering", context: :project

    specify "with 1 meeting listed" do
      invite_to_meeting(meeting)
      meetings_page.visit!

      meetings_page.expect_meetings_listed(meeting)
    end

    it "renders a link to each meeting's location if present and a valid URL" do
      invite_to_meeting(meeting)
      invite_to_meeting(meeting_with_no_location)
      invite_to_meeting(meeting_with_malicious_location)
      invite_to_meeting(tomorrows_meeting)

      meetings_page.visit!
      meetings_page.expect_link_to_meeting_location(meeting)
      meetings_page.expect_plaintext_meeting_location(tomorrows_meeting)
      meetings_page.expect_plaintext_meeting_location(meeting_with_malicious_location)
      meetings_page.expect_no_meeting_location(meeting_with_no_location)
    end
  end

  describe "top level menu items and breadcrumbs (Regression #61343)" do
    let(:meetings_page) { Pages::Meetings::Index.new(project: nil) }

    context "when the user is logged in and specific filters are selected" do
      it "shows the correct selected menu item and breadcrumb each time" do
        meetings_page.visit!

        expect(page).to have_css(".op-submenu--item-action.selected", text: "My meetings")
        expect(page).to have_css("li.breadcrumb-item-selected", text: "My meetings")

        meetings_page.set_sidebar_filter("Recurring meetings")

        expect(page).to have_css(".op-submenu--item-action.selected", text: "Recurring meetings")
        expect(page).to have_css("li.breadcrumb-item-selected", text: "Recurring meetings")

        meetings_page.set_sidebar_filter("All meetings")

        expect(page).to have_css(".op-submenu--item-action.selected", text: "All meetings")
        expect(page).to have_css("li.breadcrumb-item-selected", text: "All meetings")
      end
    end
  end

  describe "top level menu items and breadcrumbs anonymously (Regression #61343)" do
    let(:user) do
      create(:anonymous_role, permissions: %i[view_project view_meetings])
      User.anonymous
    end
    let(:project) { create(:public_project, enabled_module_names: %i[meetings]) }
    let(:meetings_page) { Pages::Meetings::Index.new(project:) }

    context "when the user is logged out and specific filters are selected", with_settings: { login_required?: false } do
      it "shows the correct selected menu item and breadcrumb each time" do
        meetings_page.visit!

        # with no filter
        expect(page).to have_css(".op-submenu--item-action.selected", text: "All meetings")
        expect(page).to have_css("li.breadcrumb-item-selected", text: "All meetings")

        meetings_page.set_sidebar_filter("Recurring meetings")

        expect(page).to have_css(".op-submenu--item-action.selected", text: "Recurring meetings")
        expect(page).to have_css("li.breadcrumb-item-selected", text: "Recurring meetings")

        # with an explicitly selected filter
        meetings_page.set_sidebar_filter("All meetings")

        expect(page).to have_css(".op-submenu--item-action.selected", text: "All meetings")
        expect(page).to have_css("li.breadcrumb-item-selected", text: "All meetings")
      end
    end
  end
end
