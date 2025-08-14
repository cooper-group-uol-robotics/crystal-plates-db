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

## Stock Solutions API

### List All Stock Solutions
- **GET** `/api/v1/stock_solutions`
- **Description**: Get all stock solutions with component information
- **Query Parameters**:
  - `search` (string, optional): Filter by name
- **Response**: Array of stock solution objects with components
- **Example Response**:
  ```json
  [
    {
      "id": 1,
      "name": "Buffer A",
      "description": "Tris-HCl buffer pH 7.4",
      "display_name": "Buffer A",
      "component_summary": "Tris-HCl (50 mM), NaCl (150 mM)",
      "used_in_wells_count": 5,
      "can_be_deleted": false,
      "created_at": "2025-07-19T10:00:00Z",
      "updated_at": "2025-07-19T10:00:00Z"
    }
  ]
  ```

### Get Stock Solution Details
- **GET** `/api/v1/stock_solutions/:id`
- **Description**: Get detailed information about a specific stock solution
- **Parameters**: 
  - `id` (integer): Stock solution ID
- **Response**: Detailed stock solution object with full component list
- **Example Response**:
  ```json
  {
    "id": 1,
    "name": "Buffer A",
    "description": "Tris-HCl buffer pH 7.4",
    "display_name": "Buffer A",
    "component_summary": "Tris-HCl (50 mM), NaCl (150 mM)",
    "used_in_wells_count": 5,
    "can_be_deleted": false,
    "created_at": "2025-07-19T10:00:00Z",
    "updated_at": "2025-07-19T10:00:00Z",
    "components": [
      {
        "id": 1,
        "chemical": {
          "id": 1,
          "name": "Tris-HCl"
        },
        "amount": 50.0,
        "unit": {
          "id": 1,
          "name": "Millimolar",
          "symbol": "mM"
        },
        "display_amount": "50.0 mM",
        "formatted_component": "Tris-HCl (50.0 mM)"
      }
    ]
  }
  ```

### Create Stock Solution
- **POST** `/api/v1/stock_solutions`
- **Description**: Create a new stock solution
- **Body Parameters**:
  ```json
  {
    "stock_solution": {
      "name": "Buffer Solution A",
      "description": "Tris-HCl buffer pH 7.4"
    }
  }
  ```
- **Response**: Created stock solution object

### Update Stock Solution
- **PUT/PATCH** `/api/v1/stock_solutions/:id`
- **Description**: Update stock solution information
- **Body Parameters**: Same as create
- **Response**: Updated stock solution object

### Delete Stock Solution
- **DELETE** `/api/v1/stock_solutions/:id`
- **Description**: Delete a stock solution
- **Response**: Success message

## Chemicals API

### Search Chemicals
- **GET** `/api/v1/chemicals/search`
- **Description**: Search chemicals by name, CAS number, or barcode
- **Query Parameters**:
  - `q` (string, required): Search query
- **Response**: Array of matching chemical objects with display text
- **Example Response**:
  ```json
  [
    {
      "id": 1,
      "name": "Tris-HCl",
      "cas": "1185-53-1",
      "barcode": "CHEM001",
      "display_text": "Tris-HCl (CAS: 1185-53-1)"
    }
  ]
  ```

## Plates API

### List All Plates
- **GET** `/api/v1/plates`
- **Description**: Get all plates with basic information
- **Query Parameters**:
  - `assigned` (boolean, optional): Filter plates by assignment status
    - `true`: Only show plates assigned to locations
    - `false`: Only show unassigned plates
- **Response**: Array of plate objects with current location and wells count
- **Examples**:
  - `GET /api/v1/plates` - Get all plates
  - `GET /api/v1/plates?assigned=false` - Get only unassigned plates
  - `GET /api/v1/plates?assigned=true` - Get only assigned plates

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
- **Description**: Move a plate to a specific location or unassign it
- **Body Parameters**:
  ```json
  {
    "location_id": 123
  }
  ```
  Or to unassign a plate:
  ```json
  {
    "location_id": null
  }
  ```
- **Response**: Plate and location information

### Unassign Plate from Location
- **POST** `/api/v1/plates/:barcode/unassign_location`
- **Description**: Remove a plate from its current location (set to unassigned)
- **Body Parameters**: None required
- **Response**: Plate information with null location

### Get Plate Location History
- **GET** `/api/v1/plates/:barcode/location_history`
- **Description**: Get the movement history of a plate
- **Response**: Array of location movements with timestamps

## Locations API

### List All Locations
- **GET** `/api/v1/locations`
- **Description**: Get all locations with optional filtering
- **Query Parameters**:
  - `name` (string, optional): Filter by location name (partial match, case-insensitive)
  - `carousel_position` (integer, optional): Filter by specific carousel position
  - `hotel_position` (integer, optional): Filter by specific hotel position
- **Response**: Array of location objects
- **Example**: 
  - `GET /api/v1/locations?name=storage` - Find locations with "storage" in the name
  - `GET /api/v1/locations?carousel_position=5` - Find locations at carousel position 5
  - `GET /api/v1/locations?hotel_position=10` - Find locations at hotel position 10
  - `GET /api/v1/locations?carousel_position=5&hotel_position=10` - Find specific carousel location

### List Carousel Locations
- **GET** `/api/v1/locations/carousel`
- **Description**: Get only carousel/hotel positions
- **Response**: Array of carousel location objects

### List Special Locations
- **GET** `/api/v1/locations/special`
- **Description**: Get only special named locations
- **Response**: Array of special location objects

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

### Unassign Plate from Location
- **POST** `/api/v1/locations/:id/unassign_all_plates`
- **Description**: Unassign plate currently at this location, making it unassigned
- **Response**: Success message with details of unassigned plate
- **Example Response** (success):
  ```json
  {
    "data": {
      "location": {
        "id": 1,
        "name": null,
        "carousel_position": 1,
        "hotel_position": 5,
        "display_name": "Carousel 1, Hotel 5"
      },
      "plates_unassigned": [
        {
          "barcode": "PLATE001",
          "status": "success"
        }
      ],
      "message": "Successfully unassigned 1 plates from location Carousel 1, Hotel 5"
    },
    "message": "All plates unassigned successfully"
  }
  ```
- **Example Response** (no plates):
  ```json
  {
    "data": {
      "location": { ... },
      "plates_unassigned": [],
      "message": "No plates found at location Carousel 1, Hotel 5"
    },
    "message": "No plates to unassign"
  }
  ```
- **Usage Example**:
  ```bash
  curl -X POST "http://localhost:3000/api/v1/locations/1/unassign_all_plates" \
    -H "Content-Type: application/json"
  ```

## Wells API

### List Wells
- **GET** `/api/v1/wells`
- **GET** `/api/v1/plates/:barcode/wells`
- **Description**: Get wells (all or for specific plate) with stock solution content counts
- **Response**: Array of well objects with content and image counts

### Get Well Details
- **GET** `/api/v1/wells/:id`
- **Description**: Get detailed well information including stock solution contents
- **Response**: Well object with stock solution contents and images
- **Example Response**:
  ```json
  {
    "id": 1,
    "plate_id": 1,
    "well_row": 1,
    "well_column": 1,
    "subwell": 1,
    "well_label": "A1",
    "well_label_with_subwell": "A1-1",
    "plate_barcode": "PLATE001",
    "x_mm": 12.5000,
    "y_mm": 8.7500,
    "z_mm": 1.0000,
    "has_coordinates": true,
    "well_contents": [
      {
        "id": 1,
        "stock_solution": "Buffer A",
        "volume": "50.0 μL"
      }
    ],
    "images": [
      {
        "id": 1,
        "filename": "image_001.jpg",
        "description": "Crystal formation",
        "captured_at": "2025-07-19T10:00:00Z"
      }
    ]
  }
  ```

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
      "well_column": 1,
      "subwell": 1,
      "x_mm": 12.5000,
      "y_mm": 8.7500,
      "z_mm": 1.0000
    }
  }
  ```
  **Note**: `x_mm`, `y_mm`, `z_mm` are optional coordinate fields in millimeters with up to 4 decimal places precision.
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

### Create a stock solution
```bash
# Create stock solution
curl -X POST http://localhost:3000/api/v1/stock_solutions \
  -H "Content-Type: application/json" \
  -d '{"stock_solution": {"name": "Buffer A", "description": "Tris-HCl pH 7.4"}}'

# Search stock solutions
curl "http://localhost:3000/api/v1/stock_solutions?search=buffer"
```

### Search chemicals
```bash
# Search chemicals by name, CAS, or barcode
curl "http://localhost:3000/api/v1/chemicals/search?q=tris"
```

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
