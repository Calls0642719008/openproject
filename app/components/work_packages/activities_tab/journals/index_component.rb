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
      class IndexComponent < ApplicationComponent
        MAX_RECENT_JOURNALS = 30

        include ApplicationHelper
        include OpPrimer::ComponentHelpers
        include OpTurbo::Streamable
        include WorkPackages::ActivitiesTab::SharedHelpers

        def initialize(work_package:, filter: :all, deferred: false)
          super

          @work_package = work_package
          @filter = filter
          @deferred = deferred
        end

        private

        attr_reader :work_package, :filter, :deferred

        def insert_target_modified?
          true
        end

        def insert_target_modifier_id
          "work-package-journal-days"
        end

        def base_journals
          combine_and_sort_records(fetch_journals, fetch_revisions)
        end

        def fetch_journals
          API::V3::Activities::ActivityEagerLoadingWrapper.wrap(
            work_package
              .journals
              .internal_visible
              .includes(:user, :customizable_journals, :attachable_journals, :storable_journals, :notifications)
              .reorder(version: journal_sorting)
              .with_sequence_version
          )
        end

        def fetch_revisions
          work_package.changesets.includes(:user, :repository)
        end

        def combine_and_sort_records(journals, revisions)
          (journals + revisions).sort_by do |record|
            timestamp = record_timestamp(record)
            journal_sorting.desc? ? [-timestamp, -record.id] : [timestamp, record.id]
          end
        end

        def record_timestamp(record)
          if record.is_a?(API::V3::Activities::ActivityEagerLoadingWrapper)
            record.created_at&.to_i
          elsif record.is_a?(Changeset)
            record.committed_on.to_i
          end
        end

        def journals
          base_journals
        end

        def recent_journals
          if journal_sorting.desc?
            base_journals.first(MAX_RECENT_JOURNALS)
          else
            base_journals.last(MAX_RECENT_JOURNALS)
          end
        end

        def older_journals
          if journal_sorting.desc?
            base_journals.drop(MAX_RECENT_JOURNALS)
          else
            base_journals.take(base_journals.size - MAX_RECENT_JOURNALS)
          end
        end

        def journal_with_notes
          work_package
            .journals
            .where.not(notes: "")
        end

        def wp_journals_grouped_emoji_reactions
          @wp_journals_grouped_emoji_reactions ||=
            EmojiReactions::GroupedQueries.grouped_work_package_journals_emoji_reactions_by_reactable(work_package)
        end

        def empty_state?
          filter == :only_comments && journal_with_notes.empty?
        end

        def inner_container_margin_bottom
          if journal_sorting.desc?
            3
          else
            0
          end
        end
      end
    end
  end
end
