# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_11_142716) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "calorimetry_datapoints", force: :cascade do |t|
    t.integer "calorimetry_dataset_id", null: false
    t.decimal "timestamp_seconds", precision: 8, scale: 3, null: false
    t.decimal "temperature", precision: 8, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calorimetry_dataset_id", "timestamp_seconds"], name: "index_calorimetry_datapoints_on_dataset_and_timestamp"
    t.index ["calorimetry_dataset_id"], name: "index_calorimetry_datapoints_on_calorimetry_dataset_id"
  end

  create_table "calorimetry_datasets", force: :cascade do |t|
    t.integer "well_id", null: false
    t.integer "calorimetry_experiment_id", null: false
    t.string "name"
    t.integer "pixel_x"
    t.integer "pixel_y"
    t.integer "mask_diameter_pixels"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calorimetry_experiment_id"], name: "index_calorimetry_datasets_on_calorimetry_experiment_id"
    t.index ["well_id"], name: "index_calorimetry_datasets_on_well_id"
  end

  create_table "calorimetry_experiments", force: :cascade do |t|
    t.integer "plate_id", null: false
    t.string "name"
    t.text "description"
    t.datetime "recorded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plate_id"], name: "index_calorimetry_experiments_on_plate_id"
  end

  create_table "chemicals", force: :cascade do |t|
    t.integer "sciformation_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "smiles"
    t.string "cas"
    t.string "amount"
    t.text "storage"
    t.string "barcode"
    t.string "empirical_formula"
    t.index ["barcode"], name: "index_chemicals_on_barcode"
    t.index ["cas"], name: "index_chemicals_on_cas"
    t.index ["name"], name: "index_chemicals_on_name"
  end

  create_table "custom_attributes", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "data_type", default: "numeric", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_custom_attributes_on_name"
    t.index ["name"], name: "index_custom_attributes_on_name_unique", unique: true
  end

  create_table "diffraction_images", force: :cascade do |t|
    t.integer "scxrd_dataset_id", null: false
    t.integer "run_number", null: false
    t.integer "image_number", null: false
    t.string "filename", null: false
    t.bigint "file_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scxrd_dataset_id", "run_number", "image_number"], name: "index_diffraction_images_on_dataset_run_image", unique: true
    t.index ["scxrd_dataset_id", "run_number"], name: "index_diffraction_images_on_scxrd_dataset_id_and_run_number"
    t.index ["scxrd_dataset_id"], name: "index_diffraction_images_on_scxrd_dataset_id"
  end

  create_table "images", force: :cascade do |t|
    t.integer "well_id", null: false
    t.decimal "pixel_size_x_mm", precision: 10, scale: 6, null: false
    t.decimal "pixel_size_y_mm", precision: 10, scale: 6, null: false
    t.decimal "reference_x_mm", precision: 12, scale: 6, null: false
    t.decimal "reference_y_mm", precision: 12, scale: 6, null: false
    t.decimal "reference_z_mm", precision: 12, scale: 6, null: false
    t.integer "pixel_width"
    t.integer "pixel_height"
    t.string "description"
    t.datetime "captured_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["captured_at"], name: "index_images_on_captured_at"
    t.index ["well_id"], name: "index_images_on_well_id"
  end

  create_table "lattice_centrings", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol"], name: "index_lattice_centrings_on_symbol", unique: true
  end

  create_table "locations", force: :cascade do |t|
    t.integer "carousel_position"
    t.integer "hotel_position"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carousel_position", "hotel_position"], name: "index_locations_on_carousel_and_hotel_positions", unique: true, where: "carousel_position IS NOT NULL AND hotel_position IS NOT NULL"
    t.index ["name"], name: "index_locations_on_name", unique: true, where: "name IS NOT NULL AND carousel_position IS NULL AND hotel_position IS NULL"
  end

  create_table "plate_locations", force: :cascade do |t|
    t.integer "plate_id", null: false
    t.integer "location_id"
    t.datetime "moved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_plate_locations_on_location_id"
    t.index ["plate_id"], name: "index_plate_locations_on_plate_id"
  end

  create_table "plate_prototypes", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "plates", force: :cascade do |t|
    t.string "barcode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rows", default: 8, null: false
    t.integer "columns", default: 12, null: false
    t.integer "subwells_per_well", default: 1, null: false
    t.datetime "deleted_at"
    t.string "name"
    t.integer "plate_prototype_id"
    t.index ["barcode"], name: "index_plates_on_barcode", unique: true
    t.index ["deleted_at"], name: "index_plates_on_deleted_at"
    t.index ["plate_prototype_id"], name: "index_plates_on_plate_prototype_id"
    t.check_constraint "columns > 0 AND columns <= 48", name: "plates_columns_range"
    t.check_constraint "rows > 0 AND rows <= 26", name: "plates_rows_range"
    t.check_constraint "subwells_per_well > 0 AND subwells_per_well <= 16", name: "plates_subwells_range"
  end

  create_table "point_of_interests", force: :cascade do |t|
    t.integer "image_id", null: false
    t.integer "pixel_x", null: false
    t.integer "pixel_y", null: false
    t.string "point_type", default: "crystal", null: false
    t.text "description"
    t.datetime "marked_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["image_id", "pixel_x", "pixel_y"], name: "index_poi_on_image_and_coordinates"
    t.index ["image_id"], name: "index_point_of_interests_on_image_id"
    t.index ["marked_at"], name: "index_point_of_interests_on_marked_at"
    t.index ["point_type"], name: "index_point_of_interests_on_point_type"
  end

  create_table "prototype_wells", force: :cascade do |t|
    t.integer "plate_prototype_id", null: false
    t.integer "well_row"
    t.integer "well_column"
    t.integer "subwell"
    t.decimal "x_mm"
    t.decimal "y_mm"
    t.decimal "z_mm"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plate_prototype_id"], name: "index_prototype_wells_on_plate_prototype_id"
  end

  create_table "pxrd_patterns", force: :cascade do |t|
    t.bigint "well_id"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "measured_at"
    t.index ["well_id"], name: "index_pxrd_patterns_on_well_id"
  end

  create_table "scxrd_datasets", force: :cascade do |t|
    t.integer "well_id"
    t.string "experiment_name", null: false
    t.float "primitive_a"
    t.float "primitive_b"
    t.float "primitive_c"
    t.float "primitive_alpha"
    t.float "primitive_beta"
    t.float "primitive_gamma"
    t.datetime "measured_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "real_world_x_mm", precision: 8, scale: 3
    t.decimal "real_world_y_mm", precision: 8, scale: 3
    t.decimal "real_world_z_mm", precision: 8, scale: 3
    t.text "processing_log"
    t.index ["well_id"], name: "index_scxrd_datasets_on_well_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "stock_solution_components", force: :cascade do |t|
    t.integer "stock_solution_id", null: false
    t.integer "chemical_id", null: false
    t.float "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "unit_id", null: false
    t.index ["chemical_id"], name: "index_stock_solution_components_on_chemical_id"
    t.index ["stock_solution_id"], name: "index_stock_solution_components_on_stock_solution_id"
    t.index ["unit_id"], name: "index_stock_solution_components_on_unit_id"
  end

  create_table "stock_solutions", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "units", force: :cascade do |t|
    t.string "name"
    t.string "symbol"
    t.float "conversion_to_base"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "well_contents", force: :cascade do |t|
    t.integer "well_id", null: false
    t.integer "stock_solution_id"
    t.float "volume"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "unit_id"
    t.string "contentable_type"
    t.integer "contentable_id"
    t.decimal "mass", precision: 10, scale: 4
    t.integer "mass_unit_id"
    t.index ["contentable_type", "contentable_id"], name: "index_well_contents_on_contentable_type_and_contentable_id"
    t.index ["mass_unit_id"], name: "index_well_contents_on_mass_unit_id"
    t.index ["stock_solution_id"], name: "index_well_contents_on_stock_solution_id"
    t.index ["unit_id"], name: "index_well_contents_on_unit_id"
    t.index ["well_id"], name: "index_well_contents_on_well_id"
  end

  create_table "well_scores", force: :cascade do |t|
    t.integer "well_id", null: false
    t.integer "custom_attribute_id", null: false
    t.decimal "value", precision: 10, scale: 3
    t.text "string_value"
    t.json "json_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_attribute_id"], name: "index_well_scores_on_custom_attribute_id"
    t.index ["well_id", "custom_attribute_id"], name: "index_well_scores_uniqueness", unique: true
    t.index ["well_id"], name: "index_well_scores_on_well_id"
  end

  create_table "wells", force: :cascade do |t|
    t.integer "plate_id", null: false
    t.integer "well_row"
    t.integer "well_column"
    t.integer "subwell"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "x_mm", precision: 10, scale: 4
    t.decimal "y_mm", precision: 10, scale: 4
    t.decimal "z_mm", precision: 10, scale: 4
    t.index ["plate_id"], name: "index_wells_on_plate_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "calorimetry_datapoints", "calorimetry_datasets"
  add_foreign_key "calorimetry_datasets", "calorimetry_experiments"
  add_foreign_key "calorimetry_datasets", "wells"
  add_foreign_key "calorimetry_experiments", "plates"
  add_foreign_key "diffraction_images", "scxrd_datasets"
  add_foreign_key "images", "wells"
  add_foreign_key "plate_locations", "locations"
  add_foreign_key "plate_locations", "plates"
  add_foreign_key "plates", "plate_prototypes"
  add_foreign_key "point_of_interests", "images"
  add_foreign_key "prototype_wells", "plate_prototypes"
  add_foreign_key "pxrd_patterns", "wells", on_delete: :nullify
  add_foreign_key "scxrd_datasets", "wells"
  add_foreign_key "stock_solution_components", "chemicals"
  add_foreign_key "stock_solution_components", "stock_solutions"
  add_foreign_key "stock_solution_components", "units"
  add_foreign_key "well_contents", "stock_solutions"
  add_foreign_key "well_contents", "units"
  add_foreign_key "well_contents", "units", column: "mass_unit_id"
  add_foreign_key "well_contents", "wells"
  add_foreign_key "well_scores", "custom_attributes"
  add_foreign_key "well_scores", "wells"
  add_foreign_key "wells", "plates"
end
