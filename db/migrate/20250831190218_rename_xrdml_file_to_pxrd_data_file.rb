class RenameXrdmlFileToPxrdDataFile < ActiveRecord::Migration[8.0]
  def change
    # Rename the Active Storage attachment from xrdml_file to pxrd_data_file
    # This updates the active_storage_attachments table
    execute <<-SQL
      UPDATE active_storage_attachments#{' '}
      SET name = 'pxrd_data_file'#{' '}
      WHERE record_type = 'PxrdPattern' AND name = 'xrdml_file';
    SQL
  end
end
