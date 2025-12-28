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

module OpPrimer
  # A simple component to render warning text.
  #
  # The warning text is rendered in the "attention" Primer color and
  # uses a leading alert Octicon for additional emphasis. This component
  # is designed to be used "inline", e.g. table cells, and in places
  # where a Banner component might be overkill.
  class WarningText < Primer::Component # rubocop:disable OpenProject/AddPreviewForViewComponent
    # @param show_warning_label [Boolean] whether to show a leading "Warning:" label
    # @param system_arguments [Hash] <%= link_to_system_arguments_docs %>
    def initialize(show_warning_label: true, **system_arguments)
      super()

      @show_warning_label = show_warning_label
      @system_arguments = system_arguments
      @system_arguments[:display] = :inline_flex
      @system_arguments[:align_items] = :center
      @system_arguments[:color] = :attention
    end

    def show_warning_label?
      !!@show_warning_label
    end

    def render?
      content.present?
    end
  end
end
