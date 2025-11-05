class RenameCalorimetryVideosToCalorimetryExperiments < ActiveRecord::Migration[8.0]
  def up
    # Rename the main table
    rename_table :calorimetry_videos, :calorimetry_experiments

    # Update foreign key column in calorimetry_datasets
    rename_column :calorimetry_datasets, :calorimetry_video_id, :calorimetry_experiment_id

    # Safely handle index rename - check if old index exists first
    if index_exists?(:calorimetry_datasets, :calorimetry_video_id, name: 'index_calorimetry_datasets_on_calorimetry_video_id')
      rename_index :calorimetry_datasets, 
                   :index_calorimetry_datasets_on_calorimetry_video_id,
                   :index_calorimetry_datasets_on_calorimetry_experiment_id
    elsif !index_exists?(:calorimetry_datasets, :calorimetry_experiment_id, name: 'index_calorimetry_datasets_on_calorimetry_experiment_id')
      # Create the index if it doesn't exist
      add_index :calorimetry_datasets, :calorimetry_experiment_id, name: 'index_calorimetry_datasets_on_calorimetry_experiment_id'
    end

    # Update any foreign key constraints (if they exist)
    if foreign_key_exists?(:calorimetry_datasets, :calorimetry_videos)
      remove_foreign_key :calorimetry_datasets, :calorimetry_videos
      add_foreign_key :calorimetry_datasets, :calorimetry_experiments
    end
  end

  def down
    # Reverse the changes
    if foreign_key_exists?(:calorimetry_datasets, :calorimetry_experiments)
      remove_foreign_key :calorimetry_datasets, :calorimetry_experiments
      add_foreign_key :calorimetry_datasets, :calorimetry_videos
    end

    if index_exists?(:calorimetry_datasets, :calorimetry_experiment_id, name: 'index_calorimetry_datasets_on_calorimetry_experiment_id')
      rename_index :calorimetry_datasets,
                   :index_calorimetry_datasets_on_calorimetry_experiment_id,
                   :index_calorimetry_datasets_on_calorimetry_video_id
    end

    rename_column :calorimetry_datasets, :calorimetry_experiment_id, :calorimetry_video_id
    rename_table :calorimetry_experiments, :calorimetry_videos
  end
end
