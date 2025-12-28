# frozen_string_literal: true

class DeleteOldMeetingContents < ActiveRecord::Migration[8.0]
  def up
    execute("DROP TABLE meeting_contents")
    execute("DROP TABLE meeting_content_journals")
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "The old meeting contents cannot be restored."
  end
end
