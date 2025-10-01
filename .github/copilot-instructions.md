# Crystal Plates Database - AI Coding Instructions

## Architecture Overview

This is a **Rails 8.0 laboratory plate and data management system** with dual interfaces:

- **Web UI**: Full CRUD operations with location tracking and grid visualization
- **REST API** (`/api/v1/*`): Complete API coverage for programmatic access

### Modern Rails 8 Stack

- **Asset Pipeline**: Propshaft (Rails 8 default, migrated from Sprockets)
- **JavaScript**: Importmap + ES6 modules, no build step required
- **Turbo Integration**: Partially implemented (causes issues, needs gradual adoption)
- **CSS**: Dartsass-rails for modern SCSS compilation

### Core Domain Models

- **Plate**: Laboratory plates with auto-generated wells and location tracking
- **Location**: Carousel positions (grid coordinates) or named special locations
- **PlateLocation**: Junction table providing movement history and audit trail
- **Well**: Individual plate positions with chemical content and imaging data
- **Image/PXRD/SCXRD**: Scientific data attached to wells with file storage

### Key Business Logic

- **Location validation**: Only one plate per location (enforced by complex scoping in `Location#current_plates`)
- **Soft deletes**: Plates use `acts_as_paranoid` for safe deletion
- **Movement tracking**: All plate moves create audit records in `plate_locations`
- **Grid visualization**: 10×20 carousel layout (carousel × hotel positions)

## Development Workflows

### Setup & Testing

```bash
bundle install
rails db:create db:migrate db:seed  # Full database setup
rails test                          # Run all tests
rails test test/controllers/api/    # API-specific tests
./bin/dev                          # Start development server
```

### Code Quality

```bash
rubocop                            # Linting (configured)
bundle exec rails test             # Full test suite
```

## API Architecture Patterns

### Controller Structure

- **Base controller** (`Api::V1::BaseController`): Handles JSON format, CSRF skipping, and consistent error responses
- **Nested resources**: Wells belong to plates, images/patterns belong to wells
- **Custom actions**: `move_to_location`, `unassign_location`, location `history`

### Response Format

```ruby
# Success (some endpoints wrap in 'data', others return directly)
{ "data": {...}, "message": "..." }
# Error
{ "error": "...", "details": [...] }
```

### Route Patterns

- Plates use `:barcode` param instead of `:id`
- Nested routes: `/plates/:barcode/wells/:id/images/:id/points_of_interest`
- Utility endpoints: `/health`, `/stats`

## Testing Conventions

### Fixture Usage

- Use fixtures extensively (see `test/fixtures/`)
- Common pattern: `@plate = plates(:one)`, `@well = wells(:one)`

### API Testing Structure

```ruby
# Standard API test pattern
test "should get index" do
  get api_v1_plates_url, as: :json
  assert_response :success
  json_response = JSON.parse(response.body)
  # Assert on structure and content
end
```

## Data & File Handling

### Active Storage Integration

- Images, PXRD patterns, SCXRD datasets use Active Storage
- Service classes handle complex file processing (`ScxrdFolderProcessorService`)

### Scientific Data Processing

- **WASM integration**: Optional WebAssembly for fast decompression of proprietary x-ray frames
- **Service layer**: Complex business logic isolated in `/app/services/`

## Database Patterns

### Key Relationships

```ruby
# Location tracking (complex scoping pattern)
scope :with_current_location, -> {
  joins(:plate_locations).merge(PlateLocation.most_recent_for_each_plate)
}

# Soft delete pattern
class Plate < ApplicationRecord
  acts_as_paranoid
```

### Migration Patterns

- Extensive use of junction tables for many-to-many relationships
- Optional foreign keys (wells can exist without plates for standalone data)

## Project-Specific Conventions

- **API versioning**: All APIs under `/api/v1/` namespace
- **Barcode-based routing**: Plates identified by barcode, not ID
- **Scientific naming**: PXRD (Powder X-Ray Diffraction), SCXRD (Single Crystal X-Ray Diffraction)
- **Location system**: Two-tier locations (carousel + hotel positions) OR named locations
- **Movement history**: Never delete location records, always create new ones

## Frontend Architecture & Modernization

### JavaScript Module System

- **Importmap**: Pin dependencies in `config/importmap.rb` (no bundling required)
- **ES6 Modules**: Use `import/export` syntax consistently  
- **Module Structure**: Place modules in `app/assets/javascripts/` and pin via importmap

### Turbo Adoption Strategy

- **Current State**: Turbo imported but causes compatibility issues
- **Incremental Approach**: Test Turbo on isolated pages first
- **Known Issues**: Form submissions and dynamic content updates conflict
- **Goal**: Full Turbo Drive + Frames integration for SPA-like experience

### Asset Pipeline (Propshaft)

- **Asset Location**: All assets in `app/assets/` (javascripts, stylesheets, images)
- **ES6 Modules**: Use import/export in JavaScript files, served directly by Propshaft
- **No Compilation**: Assets served as-is, no manifest or digest generation needed
- **WASM Support**: WebAssembly files configured with proper MIME types

### Scientific Visualization

- **WASM Integration**: ROD image parser for fast decompression of proprietary x-ray frames
- **Three.js**: Reciprocal lattice 3D visualization
- **Canvas APIs**: Custom heatmap rendering for SCXRD data
- **Module Loading**: Mix of importmap pins and script tags (needs standardization)

## Integration Points

- **External APIs**: Faraday HTTP client for external integrations
- **File processing**: Service classes handle ZIP archives, scientific data formats
- **Web/API duality**: Both interfaces share same models and business logic
- **Docker deployment**: Kamal-ready with comprehensive Docker setup
