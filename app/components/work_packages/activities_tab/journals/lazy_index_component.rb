# frozen_string_literal: true

# -- copyright
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
# ++

module WorkPackages
  module ActivitiesTab
    module Journals
      class LazyIndexComponent < IndexComponent
        def initialize(work_package:, journals:, paginator:, filter: :all)
          super(work_package:, filter:, deferred: false)

          @journals = journals
          @paginator = paginator
        end

        def pages
          current_page = paginator.page

          result = (1..paginator.pages).map do |page|
            if page == current_page
              page_component(page)
            else
              lazy_page_component(page)
            end
          end

          result.tap { it.reverse! if journal_sorting.asc? && paginator.pages > 1 }
        end

        def page_component(page)
          WorkPackages::ActivitiesTab::Journals::PageComponent
            .new(journals:, emoji_reactions: wp_journals_grouped_emoji_reactions, page:, filter:)
        end

        def lazy_page_component(page)
          WorkPackages::ActivitiesTab::Journals::LazyPageComponent.new(work_package:, page:)
        end

        def self.insert_target_modifier_id = "#{wrapper_key}-pages"
        delegate :insert_target_modifier_id, to: :class

        private

        attr_reader :journals, :paginator

        def insert_target_modified?
          true
        end
      end
    end
  end
end
