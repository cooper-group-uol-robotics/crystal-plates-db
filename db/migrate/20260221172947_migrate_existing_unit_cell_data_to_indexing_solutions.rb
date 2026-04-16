class MigrateExistingUnitCellDataToIndexingSolutions < ActiveRecord::Migration[8.0]
  def up
    migrated_count = 0
    skipped_count = 0
    
    ScxrdDataset.find_each do |dataset|
      # Check if this dataset has any unit cell or UB matrix data
      has_ub_data = dataset.ub11.present? && dataset.ub12.present? && dataset.ub13.present? &&
                    dataset.ub21.present? && dataset.ub22.present? && dataset.ub23.present? &&
                    dataset.ub31.present? && dataset.ub32.present? && dataset.ub33.present?
      
      has_primitive_cell = dataset.primitive_a.present? && dataset.primitive_b.present? && 
                          dataset.primitive_c.present? && dataset.primitive_alpha.present? && 
                          dataset.primitive_beta.present? && dataset.primitive_gamma.present?
      
      # Only migrate if there's actual data to migrate
      if has_ub_data || has_primitive_cell
        # Create the indexing solution with all available data
        IndexingSolution.create!(
          scxrd_dataset: dataset,
          
          # UB matrix
          ub11: dataset.ub11,
          ub12: dataset.ub12,
          ub13: dataset.ub13,
          ub21: dataset.ub21,
          ub22: dataset.ub22,
          ub23: dataset.ub23,
          ub31: dataset.ub31,
          ub32: dataset.ub32,
          ub33: dataset.ub33,
          wavelength: dataset.wavelength,
          
          # Primitive unit cell
          primitive_a: dataset.primitive_a,
          primitive_b: dataset.primitive_b,
          primitive_c: dataset.primitive_c,
          primitive_alpha: dataset.primitive_alpha,
          primitive_beta: dataset.primitive_beta,
          primitive_gamma: dataset.primitive_gamma,
          
          # Conventional unit cell
          conventional_a: dataset.conventional_a,
          conventional_b: dataset.conventional_b,
          conventional_c: dataset.conventional_c,
          conventional_alpha: dataset.conventional_alpha,
          conventional_beta: dataset.conventional_beta,
          conventional_gamma: dataset.conventional_gamma,
          conventional_bravais: dataset.conventional_bravais,
          conventional_cb_op: dataset.conventional_cb_op,
          conventional_distance: dataset.conventional_distance,
          
          # Indexing statistics
          spots_found: dataset.spots_found,
          spots_indexed: dataset.spots_indexed,
          
          # Source tracking
          source: "Migrated from dataset"
        )
        
        migrated_count += 1
      else
        skipped_count += 1
      end
    end
    
    puts "\n" + "="*80
    puts "Data Migration Complete"
    puts "="*80
    puts "Migrated datasets: #{migrated_count}"
    puts "Skipped datasets (no unit cell data): #{skipped_count}"
    puts "Total datasets: #{migrated_count + skipped_count}"
    puts "="*80 + "\n"
  end

  def down
    # Remove all migrated solutions
    IndexingSolution.where(source: "Migrated from dataset").destroy_all
    puts "Removed all migrated indexing solutions"
  end
end
