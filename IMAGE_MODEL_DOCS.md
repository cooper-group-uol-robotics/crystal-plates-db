# Image Model Documentation

## Overview
The `Image` model represents microscopy images associated with specific wells in a crystal plate. Each image stores detailed spatial metadata including pixel dimensions, real-world coordinates, and calibration information.

## Model Relationships
- `belongs_to :well` - Each image is associated with exactly one well
- `has_one_attached :file` - Uses ActiveStorage for file storage
- Each well can have multiple images (`Well has_many :images`)

## Key Fields

### Spatial Calibration
- `pixel_size_x_mm` - Physical width of one pixel in millimeters
- `pixel_size_y_mm` - Physical height of one pixel in millimeters
- `reference_x_mm` - X coordinate of the reference point (typically top-left corner)
- `reference_y_mm` - Y coordinate of the reference point
- `reference_z_mm` - Z coordinate (height/depth) of the image plane

### Image Properties
- `pixel_width` - Image width in pixels
- `pixel_height` - Image height in pixels
- `description` - Optional text description
- `captured_at` - Timestamp when the image was captured

## Calculated Properties

### Physical Dimensions
```ruby
image.physical_width_mm   # Total physical width in mm
image.physical_height_mm  # Total physical height in mm
```

### Coordinate Conversions
```ruby
# Convert pixel coordinates to real-world coordinates
real_coords = image.pixel_to_mm(pixel_x, pixel_y)
# Returns: { x: real_x_mm, y: real_y_mm, z: reference_z_mm }

# Convert real-world coordinates to pixel coordinates
pixel_coords = image.mm_to_pixel(real_x_mm, real_y_mm)
# Returns: { x: pixel_x, y: pixel_y }
```

### Spatial Queries
```ruby
# Get bounding box in real-world coordinates
bbox = image.bounding_box
# Returns: { min_x: float, min_y: float, max_x: float, max_y: float, z: float }

# Check if a point is within the image bounds
image.contains_point?(x_mm, y_mm)  # Returns true/false
```

## Usage Examples

### Creating a New Image
```ruby
well = Well.find(1)
image = well.images.build(
  pixel_size_x_mm: 0.001,      # 1 micrometer per pixel
  pixel_size_y_mm: 0.001,
  reference_x_mm: 10.0,        # Reference point at (10, 20, 5) mm
  reference_y_mm: 20.0,
  reference_z_mm: 5.0,
  description: "Phase contrast image",
  captured_at: Time.current
)

# Attach image file
image.file.attach(io: File.open("image.jpg"), filename: "image.jpg")

# Auto-populate pixel dimensions and save
image.populate_dimensions_from_file
image.save!
```

### Querying Images
```ruby
# Get recent images for a well
well.images.recent

# Get images ordered by capture time
well.images.by_capture_time

# Get all images in a specific area
images_in_area = Image.joins(:well).where(
  reference_x_mm: 10.0..15.0,
  reference_y_mm: 20.0..25.0
)
```

## API Endpoints
- `GET /wells/:well_id/images/new` - New image form
- `POST /wells/:well_id/images` - Create image
- `GET /wells/:well_id/images/:id` - Show image details (HTML/JSON)
- `GET /wells/:well_id/images/:id/edit` - Edit image form
- `PATCH /wells/:well_id/images/:id` - Update image
- `DELETE /wells/:well_id/images/:id` - Delete image

## JSON API Response
```json
{
  "id": 1,
  "pixel_size_x_mm": 0.001,
  "pixel_size_y_mm": 0.001,
  "reference_x_mm": 10.0,
  "reference_y_mm": 20.0,
  "reference_z_mm": 5.0,
  "pixel_width": 1000,
  "pixel_height": 800,
  "physical_width_mm": 1.0,
  "physical_height_mm": 0.8,
  "bounding_box": {
    "min_x": 10.0,
    "min_y": 20.0,
    "max_x": 11.0,
    "max_y": 20.8,
    "z": 5.0
  },
  "description": "Phase contrast image",
  "captured_at": "2025-07-14T14:30:00.000Z",
  "file_url": "/rails/active_storage/blobs/..."
}
```

## Database Schema
```sql
CREATE TABLE images (
  id INTEGER PRIMARY KEY,
  well_id INTEGER NOT NULL,
  pixel_size_x_mm DECIMAL(10,6) NOT NULL,
  pixel_size_y_mm DECIMAL(10,6) NOT NULL,
  reference_x_mm DECIMAL(12,6) NOT NULL,
  reference_y_mm DECIMAL(12,6) NOT NULL,
  reference_z_mm DECIMAL(12,6) NOT NULL,
  pixel_width INTEGER NOT NULL,
  pixel_height INTEGER NOT NULL,
  description TEXT,
  captured_at DATETIME,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  FOREIGN KEY (well_id) REFERENCES wells(id)
);
```
