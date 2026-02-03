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

# Paginates work package activities (journals and changesets) with support for filtering and anchor navigation.
#
# Filter modes:
# - :all - Shows all activities (default)
# - :only_comments - Shows only journals with notes
# - :only_changes - Shows only journals with detected changes using SQL heuristics
#
# Anchor format (filter is reset to :all when using anchors):
# - "comment-{journal_id}" - Navigate to specific journal by ID
# - "activity-{sequence_version}" - Navigate to journal by sequence version
#
# @param work_package [WorkPackage] The work package to paginate activities for
# @param params [Hash] Pagination and filtering parameters
#
# @option params [Integer] :page Page number (default: 1)
# @option params [Integer] :limit Records per page (default: Pagy::DEFAULT[:limit])
# @option params [Symbol] :filter Filter mode (:all, :only_comments, :only_changes)
# @option params [String] :anchor Anchor to navigate to specific journal
#
# @return [Array<Pagy, Array>] Pagy pagination object and array of activity records
class WorkPackages::ActivitiesTab::Paginator
  include Pagy::Method
  include WorkPackages::ActivitiesTab::JournalSortingInquirable

  def self.paginate(work_package, params = {})
    new(work_package, params).call
  end

  attr_reader :work_package, :params, :filter

  def initialize(work_package, params = {})
    @work_package = work_package
    @params = params
    @filter = params[:filter]&.to_sym || :all
  end

  def call
    anchor_type, target_record_id = extract_target_record_id

    pagy, records =
      if anchor_type && target_record_id
        @filter = :all # Ignore filter when jumping to specific journal
        pagy_array_for_target_journal(anchor_type, target_record_id)
      else
        pagy(:offset, base_journals, **pagy_options)
      end

    # For UI display: if user wants "oldest first" UI, reverse the array
    records = records.reverse if journal_sorting.asc?

    [pagy, records]
  end

  private

  def pagy_options
    {
      page: params[:page] || 1,
      limit: params[:limit] || Pagy::DEFAULT[:limit],
      max_pages: 100,
      request: { params: }
    }.compact
  end

  def extract_target_record_id
    anchor = params[:anchor] # e.g., "comment-78758" (without #)
    return nil unless anchor

    match = anchor.match(/^(comment|activity)-(\d+)$/)
    match && match.length == 3 ? [match[1].inquiry, match[2].to_i] : []
  end

  def pagy_array_for_target_journal(anchor_type, target_record_id)
    journals = base_journals

    target_index = journals.find_index do |record|
      if anchor_type.comment?
        record.id == target_record_id
      elsif anchor_type.activity?
        record.sequence_version == target_record_id
      else
        false
      end
    end

    if target_index
      limit = pagy_options[:limit]
      target_page = (target_index / limit) + 1
      pagy(:offset, journals, **pagy_options, page: target_page)
    else
      # Journal might be filtered out or deleted - fallback to page 1
      pagy(:offset, journals, **pagy_options, page: 1)
    end
  end

  def base_journals
    combine_and_sort_records(fetch_journals, fetch_revisions)
  end

  def fetch_journals
    API::V3::Activities::ActivityEagerLoadingWrapper.wrap(fetch_ar_journals)
  end

  def fetch_ar_journals
    journals = work_package
      .journals
      .internal_visible
      .includes(
        :user,
        :customizable_journals,
        :attachable_journals,
        :storable_journals,
        :notifications
      )
      .reorder(version: :desc) # Always fetch newest first for pagination
      .with_sequence_version

    case filter
    when :only_comments then apply_comments_only_filter(journals)
    when :only_changes then apply_changes_only_filter(journals)
    else
      journals
    end
  end

  def fetch_revisions
    return Changeset.none if filter == :only_comments

    work_package.changesets.includes(:user, :repository)
  end

  def combine_and_sort_records(journals, revisions)
    (journals + revisions).sort_by do |record|
      timestamp = record_timestamp(record)
      [-timestamp, -record.id] # Always sort DESC (newest first)
    end
  end

  def record_timestamp(record)
    if record.is_a?(API::V3::Activities::ActivityEagerLoadingWrapper)
      record.created_at&.to_i
    elsif record.is_a?(Changeset)
      record.committed_on.to_i
    end
  end

  def apply_comments_only_filter(scope)
    scope.where.not(notes: [nil, ""])
  end

  def apply_changes_only_filter(scope)
    JournalChangesFilter.apply(scope)
  end
end
