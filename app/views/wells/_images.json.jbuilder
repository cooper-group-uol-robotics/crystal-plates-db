json.array! images do |image|
  json.id image.id
  json.filename image.file.filename if image.file.attached?
  json.created_at image.created_at
  json.url url_for(image.file) if image.file.attached?
  json.thumbnail_url image.file.attached? ? url_for(image.file.variant(resize_to_limit: [200, 200])) : nil
end