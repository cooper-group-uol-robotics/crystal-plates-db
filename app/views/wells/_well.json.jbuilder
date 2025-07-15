json.extract! well, :id, :plate_id, :well_row, :well_column, :subwell, :created_at, :updated_at
json.well_label well.well_label
json.well_label_with_subwell well.well_label_with_subwell
json.url well_url(well, format: :json)
