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

module WaitHelpers
  # Wait for an element to stop being resized on the page
  #
  # Useful to wait for a primer dialog to finish opening, as they have an
  # opening animation.
  #
  # @param selector_or_element [String or Capybara::Node::Element] CSS selector or element to wait for
  # @param wait [Integer] Optional maximum time to wait in seconds, defaults to
  #   Capybara's default wait time
  def wait_for_size_animation_completion(selector_or_element, wait: Capybara.default_max_wait_time)
    element =
      case selector_or_element
      when String
        page.find(selector_or_element, wait:)
      when Capybara::Node::Element
        selector_or_element
      else
        raise ArgumentError, "Invalid selector or element"
      end
    page.document.synchronize do
      initial_position = page.evaluate_script("arguments[0].getBoundingClientRect()", element)
      sleep 0.1 # Small delay to allow for animation
      final_position = page.evaluate_script("arguments[0].getBoundingClientRect()", element)
      raise Capybara::ExpectationNotMet, "Animation not finished" unless initial_position == final_position
    end
  end
end

RSpec.configure do |config|
  config.include WaitHelpers, type: :feature
end
