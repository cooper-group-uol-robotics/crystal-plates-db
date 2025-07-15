# Crystal Plates Database REST API Documentation

## Overview

The Crystal Plates Database provides a comprehensive REST API alongside the web interface. All operations available through the web interface can also be performed via the API.

**Base URL**: `http://localhost:3000/api/v1`
**Format**: JSON
**Authentication**: Currently none (can be added later)

## Common Response Format

### Success Response
```json
{
  "data": { ... },
  "message": "Optional success message"
}
```

### Error Response
```json
{
  "error": "Error message",
  "details": ["Optional array of detailed error messages"]
}
```

## Plates API

### List All Plates
- **GET** `/api/v1/plates`
- **Description**: Get all plates with basic information
- **Response**: Array of plate objects with current location and wells count

### Get Plate Details
- **GET** `/api/v1/plates/:barcode`
- **Description**: Get detailed information about a specific plate
- **Parameters**: 
  - `barcode` (string): Plate barcode
- **Response**: Detailed plate object with wells information

### Create Plate
- **POST** `/api/v1/plates`
- **Description**: Create a new plate
- **Body Parameters**:
  ```json
  {
    "plate": {
      "barcode": "PLATE123"
    }
  }
  ```
- **Response**: Created plate object with wells

### Update Plate
- **PUT/PATCH** `/api/v1/plates/:barcode`
- **Description**: Update plate information
- **Body Parameters**: Same as create
- **Response**: Updated plate object

### Delete Plate
- **DELETE** `/api/v1/plates/:barcode`
- **Description**: Delete a plate and all its wells
- **Response**: Success message

### Move Plate to Location
- **POST** `/api/v1/plates/:barcode/move_to_location`
- **Description**: Move a plate to a specific location
- **Body Parameters**:
  ```json
  {
    "location_id": 123,
    "moved_by": "api_user"
  }
  ```
- **Response**: Plate and location information

### Get Plate Location History
- **GET** `/api/v1/plates/:barcode/location_history`
- **Description**: Get the movement history of a plate
- **Response**: Array of location movements with timestamps

## Locations API

### List All Locations
- **GET** `/api/v1/locations`
- **Description**: Get all locations
- **Response**: Array of location objects

### List Carousel Locations
- **GET** `/api/v1/locations/carousel`
- **Description**: Get only carousel/hotel positions
- **Response**: Array of carousel location objects

### List Special Locations
- **GET** `/api/v1/locations/special`
- **Description**: Get only special named locations
- **Response**: Array of special location objects

### Get Location Grid
- **GET** `/api/v1/locations/grid`
- **Description**: Get the carousel grid layout
- **Response**: 2D grid array with location and occupancy data

### Get Location Details
- **GET** `/api/v1/locations/:id`
- **Description**: Get detailed information about a location
- **Response**: Location object with current plates and occupancy info

### Create Location
- **POST** `/api/v1/locations`
- **Description**: Create a new location
- **Body Parameters** (Carousel):
  ```json
  {
    "location": {
      "carousel_position": 5,
      "hotel_position": 10
    },
    "location_type": "carousel"
  }
  ```
- **Body Parameters** (Special):
  ```json
  {
    "location": {
      "name": "storage_room"
    },
    "location_type": "special"
  }
  ```
- **Response**: Created location object

### Update Location
- **PUT/PATCH** `/api/v1/locations/:id`
- **Description**: Update location information
- **Body Parameters**: Same as create
- **Response**: Updated location object

### Delete Location
- **DELETE** `/api/v1/locations/:id`
- **Description**: Delete a location (only if not occupied)
- **Response**: Success message or error if occupied

### Get Current Plates at Location
- **GET** `/api/v1/locations/:id/current_plates`
- **Description**: Get all plates currently at this location
- **Response**: Array of plate objects

### Get Location History
- **GET** `/api/v1/locations/:id/history`
- **Description**: Get movement history for this location
- **Response**: Array of plate movements with timestamps

## Wells API

### List Wells
- **GET** `/api/v1/wells`
- **GET** `/api/v1/plates/:barcode/wells`
- **Description**: Get wells (all or for specific plate)
- **Response**: Array of well objects

### Get Well Details
- **GET** `/api/v1/wells/:id`
- **Description**: Get detailed well information
- **Response**: Well object with contents

### Create Well
- **POST** `/api/v1/wells`
- **POST** `/api/v1/plates/:barcode/wells`
- **Description**: Create a new well
- **Body Parameters**:
  ```json
  {
    "well": {
      "plate_id": 123,
      "well_row": 1,
      "well_column": 1
    }
  }
  ```
- **Response**: Created well object

### Update Well
- **PUT/PATCH** `/api/v1/wells/:id`
- **Description**: Update well information
- **Body Parameters**: Same as create
- **Response**: Updated well object

### Delete Well
- **DELETE** `/api/v1/wells/:id`
- **Description**: Delete a well
- **Response**: Success message

## Images API

### List Well Images
- **GET** `/api/v1/wells/:well_id/images`
- **Description**: Get all images for a specific well
- **Response**: Array of image objects

### Get Image Details
- **GET** `/api/v1/wells/:well_id/images/:id`
- **Description**: Get detailed information about a specific image
- **Response**: Detailed image object with metadata and file information

### Upload Image
- **POST** `/api/v1/wells/:well_id/images`
- **Description**: Upload a new image to a well with spatial metadata
- **Content-Type**: `multipart/form-data`
- **Body Parameters**:
  ```
  image[file]: (file) Image file (JPEG, PNG, etc.)
  image[pixel_size_x_mm]: (number) Physical width of one pixel in mm
  image[pixel_size_y_mm]: (number) Physical height of one pixel in mm  
  image[reference_x_mm]: (number) X coordinate of reference point in mm
  image[reference_y_mm]: (number) Y coordinate of reference point in mm
  image[reference_z_mm]: (number) Z coordinate of reference point in mm
  image[pixel_width]: (integer, optional) Image width in pixels (auto-detected if not provided)
  image[pixel_height]: (integer, optional) Image height in pixels (auto-detected if not provided)
  image[description]: (string, optional) Description or notes
  image[captured_at]: (datetime, optional) When image was captured (defaults to current time)
  ```
- **Response**: Created image object with auto-detected dimensions

### Update Image
- **PUT/PATCH** `/api/v1/wells/:well_id/images/:id`
- **Description**: Update image metadata (file cannot be changed)
- **Body Parameters**: Same as upload (excluding file)
- **Response**: Updated image object

### Delete Image
- **DELETE** `/api/v1/wells/:well_id/images/:id`
- **Description**: Delete an image and its file
- **Response**: Success message

## Utility Endpoints

### Health Check
- **GET** `/api/v1/health`
- **Description**: Check API and database health
- **Response**: System status information

### Statistics
- **GET** `/api/v1/stats`
- **Description**: Get system statistics
- **Response**: Comprehensive stats about plates, locations, and wells

## Example API Usage

### Create a plate and move it to a location
```bash
# Create plate
curl -X POST http://localhost:3000/api/v1/plates \
  -H "Content-Type: application/json" \
  -d '{"plate": {"barcode": "TEST001"}}'

# Create location
curl -X POST http://localhost:3000/api/v1/locations \
  -H "Content-Type: application/json" \
  -d '{"location": {"carousel_position": 1, "hotel_position": 1}, "location_type": "carousel"}'

# Move plate to location
curl -X POST http://localhost:3000/api/v1/plates/TEST001/move_to_location \
  -H "Content-Type: application/json" \
  -d '{"location_id": 1, "moved_by": "api_test"}'
```

### Get grid layout
```bash
curl http://localhost:3000/api/v1/locations/grid
```

### Get system statistics
```bash
curl http://localhost:3000/api/v1/stats
```

### Upload an image to a well
```bash
# Upload image with spatial metadata
curl -X POST http://localhost:3000/api/v1/wells/123/images \
  -F "image[file]=@/path/to/image.png" \
  -F "image[pixel_size_x_mm]=0.1" \
  -F "image[pixel_size_y_mm]=0.1" \
  -F "image[reference_x_mm]=0" \
  -F "image[reference_y_mm]=0" \
  -F "image[reference_z_mm]=5.0" \
  -F "image[description]=Crystal formation at 24 hours"
```

### Get images for a well
```bash
curl http://localhost:3000/api/v1/wells/123/images
```

## Error Codes

- **200**: Success
- **201**: Created
- **400**: Bad Request (missing parameters)
- **404**: Not Found
- **422**: Unprocessable Entity (validation errors)
- **500**: Internal Server Error

## Rate Limiting

Currently no rate limiting is implemented. This can be added in the future if needed.

## CORS

The API supports CORS for cross-origin requests from web applications.
