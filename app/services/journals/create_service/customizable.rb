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

class Journals::CreateService
  class Customizable < Association
    def associated?
      journable.customizable?
    end

    def cleanup_predecessor(predecessor, notes, cause)
      cleanup_predecessor_for(predecessor,
                              notes,
                              cause,
                              "customizable_journals",
                              :journal_id,
                              :id)
    end

    def insert_sql
      sanitize(<<~SQL.squish, journable_id:, journable_class_name:)
        INSERT INTO
          customizable_journals (
            journal_id,
            custom_field_id,
            value
          )
        SELECT
          #{id_from_inserted_journal_sql},
          custom_values.custom_field_id,
          #{normalize_newlines_sql('custom_values.value')}
        FROM custom_values
        WHERE
          #{only_if_created_sql}
          AND custom_values.customized_id = :journable_id
          AND custom_values.customized_type = :journable_class_name
          AND custom_values.value IS NOT NULL
          AND custom_values.value != ''
      SQL
    end

    def changes_sql
      sanitize(<<~SQL.squish, journable_id:, customized_type: journable_class_name)
        SELECT
          :journable_id AS JOURNABLE_ID
        FROM
          (
            SELECT
               custom_field_id,
               ARRAY_AGG(#{normalize_newlines_sql('custom_values.value')} ORDER BY value) AS value
            FROM
             custom_values
            WHERE
              custom_values.customized_id = :journable_id
              AND custom_values.customized_type = :customized_type
              AND custom_values.value != ''
            GROUP BY
              custom_field_id
          ) current_values
        FULL JOIN
          (
            SELECT
              custom_field_id,
              ARRAY_AGG(#{normalize_newlines_sql('customizable_journals.value')} ORDER BY value) AS value
            FROM
              customizable_journals
            WHERE
              journal_id IN (SELECT id FROM max_journals)
            GROUP BY
              custom_field_id
          ) journal_values
        ON current_values.custom_field_id = journal_values.custom_field_id
        WHERE
          current_values.value IS DISTINCT FROM journal_values.value
      SQL
    end
  end
end
