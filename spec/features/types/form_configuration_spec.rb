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

RSpec.describe "form configuration", :js, :selenium do
  shared_let(:admin) { create(:admin) }
  let(:type) { create(:type) }

  let!(:project) { create(:project, types: [type]) }
  let(:category) { create(:category, project:) }
  let(:work_package) do
    create(:work_package,
           project:,
           type:,
           done_ratio: 10,
           category:)
  end

  let(:wp_page) { Pages::FullWorkPackage.new(work_package) }
  let(:form) { Components::Admin::TypeConfigurationForm.new }

  describe "with EE token", with_ee: %i[edit_attribute_groups] do
    describe "default configuration" do
      let(:dialog) { Components::ConfirmationDialog.new }

      before do
        login_as(admin)
        visit edit_type_form_configuration_path(type)
      end

      it "resets the form properly after changes" do
        form.rename_group("Details", "Whatever")
        form.expect_attribute(key: :assignee)

        # Reset and cancel
        form.reset_button.click
        dialog.expect_open
        dialog.cancel

        expect(page).to have_css(".group-edit-handler", text: "WHATEVER")

        # Click the dialog again after some time
        # Otherwise this may cause issues due to the animation,
        # which is why sleep is okay.
        sleep 1

        # Reset and confirm
        form.reset_button.click
        dialog.expect_open
        dialog.confirm

        # Wait for page reload
        sleep 1

        expect(page).to have_no_css(".group-head", text: "WHATEVER")
        form.expect_group("details", "Details")
        form.expect_attribute(key: :assignee)
      end

      it "can remove all groups to be left with an invisible one (Regression #33592)" do
        form.remove_group "Details"
        form.remove_group "Estimates and progress"
        form.remove_group "People"
        form.remove_group "Costs"

        # Save configuration
        form.save_changes
        expect_flash(message: "Successful update.")

        form.expect_empty

        # Test the actual type backend
        type.reload
        expect(type.attribute_groups.count).to eq 1
        expect(type.attribute_groups.first.key).to eq :__empty
        expect(type.attribute_groups.first.attributes).to be_empty

        # Visit work package with that type
        wp_page.visit!
        wp_page.ensure_page_loaded

        wp_page.expect_hidden_field(:version)
        wp_page.expect_hidden_field(:assignee)
        wp_page.expect_hidden_field(:responsible)
        wp_page.expect_hidden_field(:priority)
        wp_page.expect_hidden_field(:date)
        wp_page.expect_hidden_field(:category)
        wp_page.expect_hidden_field(:done_ratio)

        groups = page.all(".attributes-group--header-text").map(&:text)
        expect(groups).to eq []
        expect(page)
          .to have_css(".work-packages--details--description", text: work_package.description)
      end

      it "allows modification of the form configuration" do
        #
        # Test default set of groups
        #
        form.expect_group "people",
                          "People",
                          { key: :assignee, translation: "Assignee" },
                          { key: :responsible, translation: "Accountable" }

        form.expect_group "estimates_and_progress",
                          "Estimates and progress",
                          { key: :estimated_time, translation: "Work" },
                          { key: :remaining_time, translation: "Remaining work" },
                          { key: :percentage_done, translation: "% Complete" },
                          { key: :spent_time, translation: "Spent time" }

        form.expect_group "details",
                          "Details",
                          { key: :category, translation: "Category" },
                          { key: :date, translation: "Date" },
                          { key: :priority, translation: "Priority" },
                          { key: :version, translation: "Version" }

        #
        # Modify configuration
        #

        # Disable version
        form.drag_and_drop(form.find_attribute_handle(:version), form.inactive_group)
        form.expect_inactive(:version)

        # Rename group
        form.rename_group("Details", "Whatever")
        form.rename_group("People", "Cool Stuff")

        # Start renaming, but cancel
        find(".group-edit-handler", text: "COOL STUFF").click
        input = find(".group-edit-in-place--input")
        input.set("FOOBAR")
        input.send_keys(:escape)
        expect(page).to have_css(".group-edit-handler", text: "COOL STUFF")
        expect(page).to have_no_css(".group-edit-handler", text: "FOOBAR")

        # Create new group
        form.add_attribute_group("New Group")
        form.move_to(:category, "New Group")

        # Delete attribute from group
        form.remove_attribute("assignee")

        # Save configuration
        form.save_changes
        expect_flash(message: "Successful update.")

        # Expect configuration to be correct now
        form.expect_no_attribute("assignee", "Cool Stuff")

        form.expect_group "Cool Stuff",
                          "Cool Stuff",
                          { key: :responsible, translation: "Accountable" }

        form.expect_group "estimates_and_progress",
                          "Estimates and progress",
                          { key: :estimated_time, translation: "Work" },
                          { key: :remaining_time, translation: "Remaining work" },
                          { key: :percentage_done, translation: "% Complete" },
                          { key: :spent_time, translation: "Spent time" }

        form.expect_group "Whatever",
                          "Whatever",
                          { key: :date, translation: "Date" }

        form.expect_group "New Group",
                          "New Group",
                          { key: :category, translation: "Category" }

        form.expect_inactive(:version)

        # Test the actual type backend
        type.reload
        expect(type.attribute_groups.map(&:key))
          .to include("Cool Stuff", :estimates_and_progress, "Whatever", "New Group")

        # Visit work package with that type
        wp_page.visit!
        wp_page.ensure_page_loaded

        # Version should be hidden
        wp_page.expect_hidden_field(:version)

        wp_page.expect_group("New Group") do
          wp_page.expect_attributes category: category.name
        end

        wp_page.expect_group("Whatever") do
          wp_page.expect_attributes combinedDate: "no start date - no finish date"
        end

        wp_page.expect_group("Cool Stuff") do
          wp_page.expect_attributes responsible: "-"
        end

        # Empty attributes should be shown on toggle
        wp_page.expect_hidden_field(:assignee)
        wp_page.expect_hidden_field(:spent_time)

        wp_page.expect_group("Estimates and progress") do
          wp_page.expect_attributes estimated_time: "-"
          wp_page.expect_attributes spent_time: "0h"
        end

        # New work package has the same configuration
        wp_page.expect_hidden_field(:assignee)
        wp_page.expect_hidden_field(:spent_time)
        wp_page.click_create_wp_button(type)

        wp_page.expect_group("Estimates and progress") do
          expect(page).to have_css(".inline-edit--container.estimatedTime")
        end

        find_by_id("work-packages--edit-actions-cancel").click
        expect(wp_page).not_to have_alert_dialog
        loading_indicator_saveguard
      end
    end

    describe "required custom field" do
      let(:custom_fields) { [custom_field] }
      let(:custom_field) { create(:issue_custom_field, :integer, is_required: true, name: "MyNumber") }
      let(:cf_identifier) { custom_field.attribute_name }
      let(:cf_identifier_api) { cf_identifier.camelcase(:lower) }

      before do
        project
        custom_field

        login_as(admin)
        visit edit_type_form_configuration_path(type)
      end

      it "shows the field" do
        # Should be initially disabled
        form.expect_inactive(cf_identifier)

        # Add into new group
        form.add_attribute_group("New Group")
        form.move_to(cf_identifier, "New Group")
        form.expect_attribute(key: cf_identifier)

        form.save_changes
        expect_flash(message: "Successful update.")
      end
    end

    describe "custom fields" do
      let(:project_cf_settings_page) { Pages::Projects::Settings::WorkPackageCustomFields.new(project) }

      let(:custom_fields) { [custom_field] }
      let(:custom_field) { create(:issue_custom_field, :integer, name: "MyNumber") }
      let(:cf_identifier) { custom_field.attribute_name }
      let(:cf_identifier_api) { cf_identifier.camelcase(:lower) }

      def add_cf_to_group
        project
        custom_field

        login_as(admin)
        visit edit_type_form_configuration_path(type)

        # Should be initially disabled
        form.expect_inactive(cf_identifier)

        # Add into new group
        form.add_attribute_group("New Group")
        form.move_to(cf_identifier, "New Group")

        # Make visible
        form.expect_attribute(key: cf_identifier)

        form.save_changes
        expect_flash(message: "Successful update.")
      end

      context "if inactive in project" do
        it "can be added to the type, but is not shown" do
          add_cf_to_group

          # Visit work package with that type
          wp_page.visit!
          wp_page.ensure_page_loaded

          # CF should be hidden
          wp_page.expect_no_group("New Group")
          wp_page.expect_attribute_hidden(cf_identifier_api)

          # Enable in project, should then be visible
          project_cf_settings_page.visit!
          expect(page).to have_css(".custom-field-#{custom_field.id} td", text: "MyNumber")
          expect(page).to have_css(".custom-field-#{custom_field.id} td", text: type.name)

          id_checkbox = find("#project_work_package_custom_field_ids_#{custom_field.id}")
          expect(id_checkbox).not_to be_checked
          id_checkbox.set(true)

          click_button "Save"

          # Visit work package with that type
          wp_page.visit!
          wp_page.ensure_page_loaded

          # Category should be hidden
          wp_page.expect_group("New Group") do
            wp_page.expect_attributes cf_identifier_api => "-"
          end
        end
      end

      context "if active in project" do
        let(:project) do
          create(:project,
                 types: [type],
                 work_package_custom_fields: custom_fields)
        end

        it "can be added to type and is visible" do
          add_cf_to_group

          # Visit work package with that type
          wp_page.visit!
          wp_page.ensure_page_loaded

          # Category should be hidden
          wp_page.expect_group("New Group") do
            wp_page.expect_attributes cf_identifier_api => "-"
          end

          # Ensure CF is checked
          project_cf_settings_page.visit!
          expect(page).to have_css(".custom-field-#{custom_field.id} td", text: "MyNumber")
          expect(page).to have_css(".custom-field-#{custom_field.id} td", text: type.name)
          expect(page).to have_css("#project_work_package_custom_field_ids_#{custom_field.id}[checked]")
        end
      end
    end
  end

  describe "without EE token", with_ee: false do
    let(:dialog) { Components::ConfirmationDialog.new }

    it "must disable adding and renaming groups" do
      login_as(admin)
      visit edit_type_form_configuration_path(type)

      find(".group-edit-handler", text: "DETAILS").click
      dialog.expect_open
    end
  end

  describe "form submission", :js, with_ee: %i[edit_attribute_groups] do
    # Regression test for double form submission happening on the form configuration page
    it "only submits the form once (Regression#70297)" do
      call_count = 0
      subscription =
        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
          payload => { controller:, action: }
          if controller == "WorkPackageTypes::FormConfigurationTabController" && action == "update"
            call_count += 1
          end
        end

      login_as(admin)
      visit edit_type_form_configuration_path(type)

      # Wait for form to load
      form.expect_group("details", "Details")

      # Simulate native mousedown -> mouseup -> click sequence
      # Including some sleep time to simulate the user actually
      # holding the mouse button for > 50ms then releasing it.
      save_button = find(".form-configuration--save")

      save_button.execute_script("this.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))")
      sleep 0.1
      save_button.execute_script("this.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }))")
      sleep 0.1
      save_button.execute_script("this.dispatchEvent(new MouseEvent('click', { bubbles: true }))")

      expect_flash(message: "Successful update.")

      ActiveSupport::Notifications.unsubscribe(subscription)
      expect(call_count).to eq(1), "Expected 1 form submission but got #{call_count}"
    end
  end
end
