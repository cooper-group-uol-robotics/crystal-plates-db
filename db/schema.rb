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

ActiveRecord::Schema[8.0].define(version: 2025_07_10_141313) do
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

  create_table "chemicals", force: :cascade do |t|
    t.integer "sciformation_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "locations", force: :cascade do |t|
    t.integer "carousel_position"
    t.integer "hotel_position"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "plate_locations", force: :cascade do |t|
    t.integer "plate_id", null: false
    t.integer "location_id", null: false
    t.datetime "moved_at"
    t.string "moved_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_plate_locations_on_location_id"
    t.index ["plate_id"], name: "index_plate_locations_on_plate_id"
  end

  create_table "plates", force: :cascade do |t|
    t.string "barcode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barcode"], name: "index_plates_on_barcode", unique: true
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
    t.integer "stock_solution_id", null: false
    t.float "volume_ul"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stock_solution_id"], name: "index_well_contents_on_stock_solution_id"
    t.index ["well_id"], name: "index_well_contents_on_well_id"
  end

  create_table "wells", force: :cascade do |t|
    t.integer "plate_id", null: false
    t.integer "well_row"
    t.integer "well_column"
    t.integer "subwell"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plate_id"], name: "index_wells_on_plate_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "plate_locations", "locations"
  add_foreign_key "plate_locations", "plates"
  add_foreign_key "stock_solution_components", "chemicals"
  add_foreign_key "stock_solution_components", "stock_solutions"
  add_foreign_key "stock_solution_components", "units"
  add_foreign_key "well_contents", "stock_solutions"
  add_foreign_key "well_contents", "wells"
  add_foreign_key "wells", "plates"
end
