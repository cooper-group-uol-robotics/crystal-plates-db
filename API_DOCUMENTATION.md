# Crystal Plates Database REST API Documentation

## Overview

The Crystal Plates Database provides a comprehensive REST API alongside the web interface. All operations available through the web interface can also be performed via the API.

**Base URL**: `http://localhost:3000/api/v1`
**Format**: JSON
**Authentication**: Currently none (can be added later)

## Table of Contents

- [Common Response Format](#common-response-format)
- [Stock Solutions API](#stock-solutions-api)
- [Chemicals API](#chemicals-api)
- [Plates API](#plates-api)
- [Locations API](#locations-api)
- [Wells API](#wells-api)
- [Images API](#images-api)
- [Points of Interest API](#points-of-interest-api)
- [PXRD Patterns API](#pxrd-patterns-api)
- [SCXRD Datasets API](#scxrd-datasets-api)
- [Utility Endpoints](#utility-endpoints)
- [Example API Usage](#example-api-usage)
- [Error Codes](#error-codes)

## Common Response Format

Most API endpoints wrap their responses in a standard format for consistency:

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

**Note**: Some endpoints may return data directly without the `data` wrapper for backwards compatibility. Always check the specific endpoint documentation for the exact response format.

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
      "display_name": "Buffer A",
      "total_components": 2,
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
    "display_name": "Buffer A",
    "total_components": 2,
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
      "stock_solution_components_attributes": [
        {
          "chemical_id": 1,
          "amount": 50.0,
          "unit_id": 1
        }
      ]
    }
  }
  ```
- **Response**: Created stock solution object with components

### Update Stock Solution
- **PUT/PATCH** `/api/v1/stock_solutions/:id`
- **Description**: Update stock solution information
- **Body Parameters**: Same as create
- **Response**: Updated stock solution object

### Delete Stock Solution
- **DELETE** `/api/v1/stock_solutions/:id`
- **Description**: Delete a stock solution (only if not used in wells)
- **Response**: Success message (204 No Content) or error if stock solution is in use
- **Error Response** (422 if in use):
  ```json
  {
    "error": "Cannot delete stock solution that is used in wells"
  }
  ```

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
      "display_text": "Tris-HCl | CAS: 1185-53-1 | Barcode: CHEM001"
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
- **Example Response**:
  ```json
  {
    "data": {
      "barcode": "PLATE001",
      "name": "Test Plate",
      "display_name": "PLATE001 - Test Plate",
      "created_at": "2025-07-19T10:00:00Z",
      "updated_at": "2025-07-19T10:00:00Z",
      "rows": 8,
      "columns": 12,
      "current_location": {
        "id": 1,
        "display_name": "Carousel 1, Hotel 5",
        "carousel_position": 1,
        "hotel_position": 5,
        "name": null
      },
      "wells": [
        {
          "id": 1,
          "well_row": 1,
          "well_column": 1,
          "position": "A1"
        }
      ],
      "points_of_interest": [],
      "points_of_interest_count": 0
    }
  }
  ```

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

### Get Plate Points of Interest
- **GET** `/api/v1/plates/:barcode/points_of_interest`
- **Description**: Get all points of interest for all wells and images in this plate
- **Response**: Array of points of interest with real-world coordinates and context
- **Example Response**:
  ```json
  {
    "data": [
      {
        "id": 1,
        "pixel_x": 150,
        "pixel_y": 200,
        "real_world_x_mm": 15.0,
        "real_world_y_mm": 20.0,
        "real_world_z_mm": 5.0,
        "point_type": "crystal",
        "description": "Large crystal",
        "marked_at": "2025-07-19T10:00:00Z",
        "display_name": "Crystal at (15.0, 20.0)",
        "created_at": "2025-07-19T10:00:00Z",
        "updated_at": "2025-07-19T10:00:00Z",
        "image": {
          "id": 1,
          "filename": "image_001.jpg",
          "well_id": 123
        },
        "well": {
          "id": 123,
          "well_row": 1,
          "well_column": 1,
          "position": "A1"
        }
      }
    ]
  }
  ```

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
    "data": {
      "id": 1,
      "well_row": 1,
      "well_column": 1,
      "subwell": 1,
      "position": "A1",
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
          "pixel_size_x_mm": 0.1,
          "pixel_size_y_mm": 0.1,
          "captured_at": "2025-07-19T10:00:00Z",
          "description": "Crystal formation",
          "file_url": "http://localhost:3000/rails/active_storage/blobs/xyz.jpg"
        }
      ],
      "created_at": "2025-07-19T10:00:00Z",
      "updated_at": "2025-07-19T10:00:00Z"
    }
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

## Points of Interest API

Points of Interest are markers placed on images to identify features like crystals or particles. They support real-world coordinate mapping based on the image's spatial metadata.

### List Points of Interest for Image
- **GET** `/api/v1/wells/:well_id/images/:image_id/points_of_interest`
- **GET** `/api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest`
- **Description**: Get all points of interest for a specific image
- **Response**: Array of point of interest objects with real-world coordinates

### List All Points of Interest
- **GET** `/api/v1/points_of_interest`
- **Description**: Get all points of interest across the system with context information
- **Response**: Array of point objects with image and well context

### Filter Points of Interest by Type
- **GET** `/api/v1/points_of_interest/by_type`
- **Description**: Get points of interest filtered by type
- **Query Parameters**:
  - `type` (string, required): Point type to filter by (e.g., "crystal", "particle")
- **Response**: Array of filtered point objects

### Get Recent Points of Interest
- **GET** `/api/v1/points_of_interest/recent`
- **Description**: Get recently created points of interest
- **Query Parameters**:
  - `limit` (integer, optional): Maximum number of results (default: 50)
- **Response**: Array of recent point objects

### Get Crystal Points
- **GET** `/api/v1/points_of_interest/crystals`
- **Description**: Get all points of interest marked as crystals
- **Response**: Array of crystal point objects

### Get Particle Points  
- **GET** `/api/v1/points_of_interest/particles`
- **Description**: Get all points of interest marked as particles
- **Response**: Array of particle point objects

### Get Point of Interest Details
- **GET** `/api/v1/wells/:well_id/images/:image_id/points_of_interest/:id`
- **GET** `/api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest/:id`
- **Description**: Get detailed information about a specific point of interest
- **Response**: Detailed point object with real-world coordinates
- **Example Response**:
  ```json
  {
    "data": {
      "id": 1,
      "pixel_x": 150,
      "pixel_y": 200,
      "real_world_x_mm": 15.0,
      "real_world_y_mm": 20.0,
      "real_world_z_mm": 5.0,
      "point_type": "crystal",
      "description": "Large crystal formation",
      "marked_at": "2025-07-19T10:00:00Z",
      "display_name": "Crystal at (15.0, 20.0)",
      "created_at": "2025-07-19T10:00:00Z",
      "updated_at": "2025-07-19T10:00:00Z"
    }
  }
  ```

### Create Point of Interest
- **POST** `/api/v1/wells/:well_id/images/:image_id/points_of_interest`
- **POST** `/api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest`
- **Description**: Create a new point of interest on an image
- **Body Parameters**:
  ```json
  {
    "point_of_interest": {
      "pixel_x": 150,
      "pixel_y": 200,
      "point_type": "crystal",
      "description": "Large crystal formation",
      "marked_at": "2025-07-19T10:00:00Z"
    }
  }
  ```
- **Response**: Created point of interest object with real-world coordinates

### Update Point of Interest
- **PUT/PATCH** `/api/v1/wells/:well_id/images/:image_id/points_of_interest/:id`
- **PUT/PATCH** `/api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest/:id`
- **Description**: Update point of interest information
- **Body Parameters**: Same as create
- **Response**: Updated point of interest object

### Delete Point of Interest
- **DELETE** `/api/v1/wells/:well_id/images/:image_id/points_of_interest/:id`
- **DELETE** `/api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest/:id`
- **Description**: Delete a point of interest
- **Response**: Success message

## PXRD Patterns API

### List All PXRD Patterns
- **GET** `/api/v1/pxrd_patterns`
- **Description**: Get all PXRD patterns across all wells
- **Response**: Array of PXRD pattern objects
- **Example Response**:
  ```json
  [
    {
      "id": 1,
      "title": "Crystal A1 - Day 3",
      "well_id": 123,
      "well_label": "A1:1",
      "plate_barcode": "PLATE001",
      "measured_at": "2025-07-19T10:00:00Z",
      "file_attached": true,
      "file_url": "http://localhost:3000/rails/active_storage/blobs/xyz.xrdml",
      "file_size": 45678,
      "created_at": "2025-07-19T10:30:00Z",
      "updated_at": "2025-07-19T10:30:00Z"
    }
  ]
  ```

### List Well PXRD Patterns
- **GET** `/api/v1/wells/:well_id/pxrd_patterns`
- **Description**: Get all PXRD patterns for a specific well
- **Response**: Array of PXRD pattern objects for the well

### Get PXRD Pattern Details
- **GET** `/api/v1/pxrd_patterns/:id`
- **Description**: Get detailed information about a specific PXRD pattern
- **Response**: Detailed PXRD pattern object
- **Example Response**:
  ```json
  {
    "id": 1,
    "title": "Crystal A1 - Day 3",
    "well_id": 123,
    "well_label": "A1:1",
    "plate_barcode": "PLATE001",
    "measured_at": "2025-07-19T10:00:00Z",
    "file_attached": true,
    "file_url": "http://localhost:3000/rails/active_storage/blobs/xyz.xrdml",
    "file_size": 45678,
    "created_at": "2025-07-19T10:30:00Z",
    "updated_at": "2025-07-19T10:30:00Z",
    "well": {
      "id": 123,
      "label": "A1:1",
      "row": 1,
      "column": 1,
      "subwell": 1,
      "plate": {
        "id": 1,
        "barcode": "PLATE001",
        "name": "Test Plate"
      }
    },
    "file_metadata": {
      "filename": "pattern_001.xrdml",
      "content_type": "application/xml",
      "byte_size": 45678,
      "created_at": "2025-07-19T10:30:00Z"
    }
  }
  ```

### Get PXRD Pattern Data
- **GET** `/api/v1/pxrd_patterns/:id/data`
- **Description**: Get the parsed diffraction data from the XRDML file
- **Response**: Diffraction data with 2θ values and intensities
- **Example Response**:
  ```json
  {
    "data": {
      "two_theta": [5.0, 5.1, 5.2, 5.3, ...],
      "intensities": [120.5, 125.8, 130.2, 128.9, ...],
      "metadata": {
        "title": "Crystal A1 - Day 3",
        "measured_at": "2025-07-19T10:00:00Z",
        "total_points": 8000
      }
    }
  }
  ```

### Upload PXRD Pattern to Well
- **POST** `/api/v1/wells/:well_id/pxrd_patterns`
- **Description**: Upload a new PXRD pattern to a specific well
- **Content-Type**: `multipart/form-data`
- **Body Parameters**:
  ```
  pxrd_pattern[title]: (string) Title or description of the pattern
  pxrd_pattern[pxrd_data_file]: (file) PXRD data file in XRDML format
  ```
- **Response**: Created PXRD pattern object with auto-parsed timestamp
- **Example**:
  ```bash
  curl -X POST http://localhost:3000/api/v1/wells/123/pxrd_patterns \
    -F "pxrd_pattern[title]=Crystal A1 - Day 3" \
    -F "pxrd_pattern[pxrd_data_file]=@/path/to/pattern.xrdml"
  ```

### Upload Standalone PXRD Pattern
- **POST** `/api/v1/pxrd_patterns`
- **Description**: Upload a new PXRD pattern not associated with a specific well
- **Content-Type**: `multipart/form-data`
- **Body Parameters**:
  ```
  pxrd_pattern[title]: (string) Title or description of the pattern
  pxrd_pattern[pxrd_data_file]: (file) PXRD data file in XRDML format
  ```
- **Response**: Created PXRD pattern object (well_id will be null)
- **Example**:
  ```bash
  curl -X POST http://localhost:3000/api/v1/pxrd_patterns \
    -F "pxrd_pattern[title]=Reference Standard - Quartz" \
    -F "pxrd_pattern[pxrd_data_file]=@/path/to/standard.xrdml"
  ```
- **Example Response**:
  ```json
  {
    "id": 15,
    "title": "Reference Standard - Quartz",
    "well_id": null,
    "well_label": null,
    "plate_barcode": null,
    "measured_at": "2025-07-19T14:30:00Z",
    "file_attached": true,
    "file_url": "http://localhost:3000/rails/active_storage/blobs/abc123.xrdml",
    "file_size": 52341,
    "created_at": "2025-09-25T10:15:00Z",
    "updated_at": "2025-09-25T10:15:00Z"
  }
  ```

### Update PXRD Pattern
- **PUT/PATCH** `/api/v1/pxrd_patterns/:id`
- **Description**: Update PXRD pattern information (title only, file cannot be changed)
- **Body Parameters**:
  ```json
  {
    "pxrd_pattern": {
      "title": "Updated title"
    }
  }
  ```
- **Response**: Updated PXRD pattern object

### Delete PXRD Pattern
- **DELETE** `/api/v1/pxrd_patterns/:id`
- **Description**: Delete a PXRD pattern and its file
- **Response**: Success message
- **Example Response**:
  ```json
  {
    "message": "PXRD pattern successfully deleted"
  }
  ```

## SCXRD Datasets API

The SCXRD (Single Crystal X-Ray Diffraction) API provides comprehensive endpoints for managing crystallographic datasets, including unit cell parameters, real-world coordinates, and spatial correlations with points of interest.

### List SCXRD Datasets

**GET** `/api/v1/wells/:well_id/scxrd_datasets`

List all SCXRD datasets for a specific well.

#### Parameters
- `well_id` (path, required) - Well ID

#### Response Example
```json
{
  "well_id": 123,
  "well_label": "A1",
  "count": 2,
  "scxrd_datasets": [
    {
      "id": 456,
      "experiment_name": "crystal_001_scan",
      "measured_at": "2024-01-15",
      "date_uploaded": "2024-01-15 14:30:22",
      "lattice_centring": "P1",
      "real_world_coordinates": {
        "x_mm": 1.234,
        "y_mm": 5.678,
        "z_mm": 2.100
      },
      "unit_cell": {
        "a": 15.457,
        "b": 15.638,
        "c": 18.121,
        "alpha": 89.9,
        "beta": 90.0,
        "gamma": 89.9
      },
      "has_archive": true,
      "has_peak_table": true,
      "has_first_image": true,
      "created_at": "2024-01-15T14:30:22.123Z",
      "updated_at": "2024-01-15T14:30:22.123Z"
    }
  ]
}
```

### Get SCXRD Dataset Details

**GET** `/api/v1/wells/:well_id/scxrd_datasets/:id`

Get detailed information about a specific SCXRD dataset.

#### Parameters
- `well_id` (path, required) - Well ID
- `id` (path, required) - SCXRD dataset ID

#### Response Example
```json
{
  "scxrd_dataset": {
    "id": 456,
    "experiment_name": "crystal_001_scan",
    "measured_at": "2024-01-15",
    "date_uploaded": "2024-01-15 14:30:22",
    "lattice_centring": "P1",
    "real_world_coordinates": {
      "x_mm": 1.234,
      "y_mm": 5.678,
      "z_mm": 2.100
    },
    "unit_cell": {
      "a": 15.457,
      "b": 15.638,
      "c": 18.121,
      "alpha": 89.9,
      "beta": 90.0,
      "gamma": 89.9
    },
    "has_archive": true,
    "has_peak_table": true,
    "has_first_image": true,
    "peak_table_size": "2.3 MB",
    "first_image_size": "15.7 MB",
    "image_metadata": {
      "detector": "Pilatus 300K",
      "wavelength": 0.71073,
      "exposure_time": 1.0
    },
    "nearby_point_of_interests": [
      {
        "id": 789,
        "point_type": "crystal",
        "pixel_coordinates": { "x": 150, "y": 200 },
        "real_world_coordinates": { "x_mm": 1.189, "y_mm": 5.723, "z_mm": 2.100 },
        "distance_mm": 0.234,
        "image_id": 101
      }
    ],
    "created_at": "2024-01-15T14:30:22.123Z",
    "updated_at": "2024-01-15T14:30:22.123Z"
  }
}
```

### Create SCXRD Dataset

**POST** `/api/v1/wells/:well_id/scxrd_datasets`

Create a new SCXRD dataset with manual unit cell parameters.

#### Parameters
- `well_id` (path, required) - Well ID

#### Request Body
```json
{
  "scxrd_dataset": {
    "experiment_name": "crystal_001_scan",
    "measured_at": "2024-01-15",
    "real_world_x_mm": 1.234,
    "real_world_y_mm": 5.678,
    "real_world_z_mm": 2.100,
    "niggli_a": 15.457,
    "niggli_b": 15.638,
    "niggli_c": 18.121,
    "niggli_alpha": 89.9,
    "niggli_beta": 90.0,
    "niggli_gamma": 89.9
  }
}
```

#### Response Example
```json
{
  "message": "SCXRD dataset created successfully",
  "scxrd_dataset": {
    "id": 456,
    "experiment_name": "crystal_001_scan"
  }
}
```

**Note**: The API currently only supports manual dataset creation with individual parameters. For bulk upload of compressed archives (ZIP files containing diffraction data, logs, and structure files), use the web interface. The web interface supports automatic processing of complete experiment folders, including:
- Automatic extraction of unit cell parameters from log files
- Processing of diffraction images (.img files)
- Extraction of structure files (.res files)
- Peak table parsing

This bulk upload capability is not yet available via API.

### Update SCXRD Dataset

**PATCH/PUT** `/api/v1/wells/:well_id/scxrd_datasets/:id`

Update an existing SCXRD dataset.

#### Parameters
- `well_id` (path, required) - Well ID
- `id` (path, required) - SCXRD dataset ID

#### Request Body
```json
{
  "scxrd_dataset": {
    "experiment_name": "updated_crystal_001_scan",
    "real_world_x_mm": 1.235,
    "a": 15.458
  }
}
```

#### Response Example
```json
{
  "message": "SCXRD dataset updated successfully",
  "scxrd_dataset": {
    "id": 456,
    "experiment_name": "updated_crystal_001_scan"
  }
}
```

### Delete SCXRD Dataset

**DELETE** `/api/v1/wells/:well_id/scxrd_datasets/:id`

Delete an SCXRD dataset.

#### Parameters
- `well_id` (path, required) - Well ID
- `id` (path, required) - SCXRD dataset ID

#### Response Example
```json
{
  "message": "SCXRD dataset deleted successfully"
}
```

### Get Diffraction Image Data

**GET** `/api/v1/wells/:well_id/scxrd_datasets/:id/image_data`

Get parsed diffraction image data for visualization.

#### Parameters
- `well_id` (path, required) - Well ID
- `id` (path, required) - SCXRD dataset ID

#### Response Example
```json
{
  "success": true,
  "dimensions": [1024, 1024],
  "pixel_size": [0.172, 0.172],
  "metadata": {
    "detector": "Pilatus 300K",
    "wavelength": 0.71073,
    "exposure_time": 1.0,
    "detector_distance": 50.0
  },
  "image_data": [12, 15, 18, 22, 25]
}
```

### Spatial Correlations

**GET** `/api/v1/wells/:well_id/scxrd_datasets/spatial_correlations`

Find spatial correlations between SCXRD datasets and points of interest.

#### Parameters
- `well_id` (path, required) - Well ID
- `tolerance_mm` (query, optional) - Distance tolerance in millimeters (default: 0.5)

#### Query String Example
```
?tolerance_mm=1.0
```

#### Response Example
```json
{
  "well_id": 123,
  "well_label": "A1",
  "tolerance_mm": 1.0,
  "correlations_count": 2,
  "correlations": [
    {
      "scxrd_dataset": {
        "id": 456,
        "experiment_name": "crystal_001_scan",
        "real_world_coordinates": {
          "x_mm": 1.234,
          "y_mm": 5.678,
          "z_mm": 2.100
        }
      },
      "point_of_interests": [
        {
          "id": 789,
          "point_type": "crystal",
          "pixel_coordinates": { "x": 150, "y": 200 },
          "real_world_coordinates": { "x_mm": 1.189, "y_mm": 5.723, "z_mm": 2.100 },
          "distance_mm": 0.234,
          "image_id": 101,
          "marked_at": "2024-01-15T12:00:00.000Z"
        }
      ]
    }
  ]
}
```

### Search SCXRD Datasets

**GET** `/api/v1/wells/:well_id/scxrd_datasets/search`

Search SCXRD datasets with various filters.

#### Parameters
- `well_id` (path, required) - Well ID

#### Query Parameters
- `experiment_name` (string, optional) - Partial match on experiment name
- `date_from` (date, optional) - Start date filter (YYYY-MM-DD)
- `date_to` (date, optional) - End date filter (YYYY-MM-DD)
- `lattice_centring` (string, optional) - Lattice centering symbol (e.g., "P1", "P21")
- `near_x` (float, optional) - X coordinate for proximity search
- `near_y` (float, optional) - Y coordinate for proximity search
- `tolerance_mm` (float, optional) - Distance tolerance for proximity search (default: 1.0)
- `unit_cell[a]` (float, optional) - Unit cell parameter a
- `unit_cell[b]` (float, optional) - Unit cell parameter b
- `unit_cell[c]` (float, optional) - Unit cell parameter c
- `unit_cell[alpha]` (float, optional) - Unit cell parameter alpha
- `unit_cell[beta]` (float, optional) - Unit cell parameter beta
- `unit_cell[gamma]` (float, optional) - Unit cell parameter gamma
- `cell_tolerance_percent` (float, optional) - Tolerance for unit cell parameters (default: 5.0%)

#### Query String Examples

**Search by experiment name:**
```
?experiment_name=crystal_001
```

**Search by date range:**
```
?date_from=2024-01-01&date_to=2024-01-31
```

**Search by proximity to coordinates:**
```
?near_x=1.234&near_y=5.678&tolerance_mm=0.5
```

**Search by unit cell parameters:**
```
?unit_cell[a]=15.5&unit_cell[b]=15.6&cell_tolerance_percent=3.0
```

**Complex search:**
```
?experiment_name=crystal&lattice_centring=P1&date_from=2024-01-01&unit_cell[a]=15.5&cell_tolerance_percent=5.0
```

#### Response Example
```json
{
  "well_id": 123,
  "search_params": {
    "experiment_name": "crystal_001",
    "lattice_centring": "P1",
    "date_from": "2024-01-01"
  },
  "results_count": 3,
  "scxrd_datasets": [
    {
      "id": 456,
      "experiment_name": "crystal_001_scan"
    }
  ]
}
```

### SCXRD Data Models

#### SCXRD Dataset Object

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Unique identifier |
| `experiment_name` | string | Name of the experiment |
| `measured_at` | date | Date when measurement was taken |
| `date_uploaded` | datetime | When dataset was uploaded |
| `lattice_centring` | string | Lattice centering symbol (P1, P21, etc.) |
| `real_world_coordinates` | object | Physical coordinates where measured |
| `real_world_coordinates.x_mm` | float | X coordinate in millimeters |
| `real_world_coordinates.y_mm` | float | Y coordinate in millimeters |
| `real_world_coordinates.z_mm` | float | Z coordinate in millimeters |
| `unit_cell` | object | Unit cell parameters |
| `unit_cell.a` | float | Unit cell parameter a (Ångström) |
| `unit_cell.b` | float | Unit cell parameter b (Ångström) |
| `unit_cell.c` | float | Unit cell parameter c (Ångström) |
| `unit_cell.alpha` | float | Unit cell parameter alpha (degrees) |
| `unit_cell.beta` | float | Unit cell parameter beta (degrees) |
| `unit_cell.gamma` | float | Unit cell parameter gamma (degrees) |
| `has_archive` | boolean | Whether archive file is attached |
| `has_peak_table` | boolean | Whether peak table is available |
| `has_first_image` | boolean | Whether diffraction image is available |
| `created_at` | datetime | Creation timestamp |
| `updated_at` | datetime | Last update timestamp |

#### Point of Interest Correlation Object

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | POI unique identifier |
| `point_type` | string | Type of point (crystal, particle, droplet, other) |
| `pixel_coordinates` | object | Pixel coordinates in image |
| `pixel_coordinates.x` | integer | X pixel coordinate |
| `pixel_coordinates.y` | integer | Y pixel coordinate |
| `real_world_coordinates` | object | Converted real-world coordinates |
| `distance_mm` | float | Distance from SCXRD dataset in millimeters |
| `image_id` | integer | Associated image ID |
| `marked_at` | datetime | When POI was marked |

### SCXRD API Usage Examples

#### Python Example

```python
import requests
import json

base_url = "http://localhost:3000/api/v1"
well_id = 123

# List all datasets
response = requests.get(f"{base_url}/wells/{well_id}/scxrd_datasets")
datasets = response.json()

# Create a new dataset
new_dataset = {
    "scxrd_dataset": {
        "experiment_name": "my_crystal_experiment",
        "measured_at": "2024-01-15",
        "real_world_x_mm": 1.234,
        "real_world_y_mm": 5.678,
        "a": 15.5,
        "b": 15.6,
        "c": 18.1
    }
}

response = requests.post(
    f"{base_url}/wells/{well_id}/scxrd_datasets",
    json=new_dataset,
    headers={"Content-Type": "application/json"}
)

# Search for datasets near specific coordinates
response = requests.get(
    f"{base_url}/wells/{well_id}/scxrd_datasets/search",
    params={
        "near_x": 1.0,
        "near_y": 5.0,
        "tolerance_mm": 0.5
    }
)

# Get spatial correlations
response = requests.get(
    f"{base_url}/wells/{well_id}/scxrd_datasets/spatial_correlations",
    params={"tolerance_mm": 1.0}
)
```

#### JavaScript Example

```javascript
const baseUrl = 'http://localhost:3000/api/v1';
const wellId = 123;

// List all datasets
const datasets = await fetch(`${baseUrl}/wells/${wellId}/scxrd_datasets`)
  .then(response => response.json());

// Create a new dataset
const newDataset = {
  scxrd_dataset: {
    experiment_name: 'my_crystal_experiment',
    measured_at: '2024-01-15',
    real_world_x_mm: 1.234,
    real_world_y_mm: 5.678,
    a: 15.5,
    b: 15.6,
    c: 18.1
  }
};

const created = await fetch(`${baseUrl}/wells/${wellId}/scxrd_datasets`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(newDataset)
}).then(response => response.json());

// Search datasets
const searchParams = new URLSearchParams({
  experiment_name: 'crystal',
  'unit_cell[a]': '15.5',
  cell_tolerance_percent: '3.0'
});

const searchResults = await fetch(
  `${baseUrl}/wells/${wellId}/scxrd_datasets/search?${searchParams}`
).then(response => response.json());
```

#### cURL Examples

```bash
# List SCXRD datasets for a well
curl http://localhost:3000/api/v1/wells/123/scxrd_datasets

# Create a new SCXRD dataset
curl -X POST http://localhost:3000/api/v1/wells/123/scxrd_datasets \
  -H "Content-Type: application/json" \
  -d '{
    "scxrd_dataset": {
      "experiment_name": "crystal_formation_day1",
      "measured_at": "2024-01-15",
      "real_world_x_mm": 1.234,
      "real_world_y_mm": 5.678,
      "real_world_z_mm": 2.100,
      "a": 15.457,
      "b": 15.638,
      "c": 18.121,
      "alpha": 89.9,
      "beta": 90.0,
      "gamma": 89.9
    }
  }'

# Search datasets by experiment name
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/search?experiment_name=crystal_001"

# Search datasets by date range
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/search?date_from=2024-01-01&date_to=2024-01-31"

# Search datasets near specific coordinates
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/search?near_x=1.234&near_y=5.678&tolerance_mm=0.5"

# Get spatial correlations with POIs
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/spatial_correlations?tolerance_mm=1.0"

# Get diffraction image data
curl http://localhost:3000/api/v1/wells/123/scxrd_datasets/456/image_data

# Update dataset coordinates
curl -X PATCH http://localhost:3000/api/v1/wells/123/scxrd_datasets/456 \
  -H "Content-Type: application/json" \
  -d '{
    "scxrd_dataset": {
      "real_world_x_mm": 1.235,
      "real_world_y_mm": 5.679
    }
  }'

# Delete a dataset
curl -X DELETE http://localhost:3000/api/v1/wells/123/scxrd_datasets/456
```

## Utility Endpoints

### Health Check
- **GET** `/api/v1/health`
- **Description**: Check API and database health
- **Response**: System status information

### Statistics
- **GET** `/api/v1/stats`
- **Description**: Get comprehensive system statistics including plates, locations, wells, and occupancy data
- **Response**: Detailed statistics object
- **Example Response**:
  ```json
  {
    "data": {
      "overview": {
        "total_plates": 150,
        "total_locations": 200,
        "total_wells": 14400,
        "occupied_locations": 75,
        "available_locations": 125
      },
      "locations": {
        "carousel_locations": 180,
        "special_locations": 20,
        "occupancy_rate": 37.5
      },
      "plates": {
        "plates_with_location": 75,
        "plates_without_location": 75,
        "recent_movements": 12
      },
      "wells": {
        "wells_with_content": 3600,
        "wells_without_content": 10800,
        "average_wells_per_plate": 96.0
      }
    }
  }
  ```

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

### Upload and work with PXRD patterns
```bash
# Upload PXRD pattern to a well
curl -X POST http://localhost:3000/api/v1/wells/123/pxrd_patterns \
  -F "pxrd_pattern[title]=Crystal formation day 5" \
  -F "pxrd_pattern[pxrd_data_file]=@/path/to/diffraction.xrdml"

# Get all PXRD patterns for a well
curl http://localhost:3000/api/v1/wells/123/pxrd_patterns

# Get parsed diffraction data
curl http://localhost:3000/api/v1/pxrd_patterns/456/data

# List all PXRD patterns in the system
curl http://localhost:3000/api/v1/pxrd_patterns
```

### Work with Points of Interest
```bash
# Create a point of interest on an image
curl -X POST http://localhost:3000/api/v1/wells/123/images/456/points_of_interest \
  -H "Content-Type: application/json" \
  -d '{
    "point_of_interest": {
      "pixel_x": 150,
      "pixel_y": 200,
      "point_type": "crystal",
      "description": "Large crystal formation"
    }
  }'

# Get all points of interest for an image
curl http://localhost:3000/api/v1/wells/123/images/456/points_of_interest

# Get all crystal points in the system
curl http://localhost:3000/api/v1/points_of_interest/crystals

# Get recent points of interest
curl "http://localhost:3000/api/v1/points_of_interest/recent?limit=20"

# Get all points of interest for a plate
curl http://localhost:3000/api/v1/plates/PLATE001/points_of_interest
```

### Work with SCXRD Datasets
```bash
# List all SCXRD datasets for a well
curl http://localhost:3000/api/v1/wells/123/scxrd_datasets

# Create a new SCXRD dataset with real-world coordinates
curl -X POST http://localhost:3000/api/v1/wells/123/scxrd_datasets \
  -H "Content-Type: application/json" \
  -d '{
    "scxrd_dataset": {
      "experiment_name": "crystal_formation_day1",
      "measured_at": "2024-01-15",
      "real_world_x_mm": 1.234,
      "real_world_y_mm": 5.678,
      "real_world_z_mm": 2.100,
      "lattice_centring_id": 1,
      "a": 15.457,
      "b": 15.638,
      "c": 18.121,
      "alpha": 89.9,
      "beta": 90.0,
      "gamma": 89.9
    }
  }'

# Search datasets by experiment name and date range
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/search?experiment_name=crystal&date_from=2024-01-01&date_to=2024-01-31"

# Find datasets near specific coordinates
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/search?near_x=1.234&near_y=5.678&tolerance_mm=0.5"

# Search by unit cell parameters with tolerance
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/search?unit_cell[a]=15.5&unit_cell[b]=15.6&cell_tolerance_percent=3.0"

# Get spatial correlations with points of interest
curl "http://localhost:3000/api/v1/wells/123/scxrd_datasets/spatial_correlations?tolerance_mm=1.0"

# Get diffraction image data for visualization
curl http://localhost:3000/api/v1/wells/123/scxrd_datasets/456/image_data

# Update dataset coordinates
curl -X PATCH http://localhost:3000/api/v1/wells/123/scxrd_datasets/456 \
  -H "Content-Type: application/json" \
  -d '{"scxrd_dataset": {"real_world_x_mm": 1.235}}'
```

## API vs Web Interface Feature Differences

While the API provides comprehensive access to most functionality, there are some differences compared to the web interface:

### Features Available Only in Web Interface

**SCXRD Bulk Upload**: The web interface supports uploading compressed archives (ZIP files) containing complete experiment folders. This includes:
- Automatic processing of diffraction data folders
- Extraction of unit cell parameters from log files  
- Processing of diffraction images (.img files)
- Automatic discovery and attachment of structure files (.res files)
- Peak table parsing and attachment

The API currently only supports manual dataset creation with individual parameters.

**Advanced File Processing**: Some specialized file processing workflows are optimized for the web interface and may not be available via API.

### Planned API Enhancements

The following features are planned for future API versions:
- Bulk upload support for SCXRD datasets
- Advanced file processing endpoints
- Batch operations for multiple records
- Enhanced search and filtering capabilities

### Non-Functional Routes

Some routes may appear in the API routes but are not currently implemented:
- Individual diffraction image access endpoints
- Some SCXRD-specific file endpoints (crystal_image, peak_table_data)
- Advanced processing endpoints

If you encounter a 404 error on a route that appears to exist, it may be one of these non-functional routes.

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
