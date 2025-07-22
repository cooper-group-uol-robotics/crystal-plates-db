# Crystal Plates Database

A comprehensive laboratory plate management system with location tracking, movement history, and a full REST API.

## Features

### Web Interface
- **Plate Management**: Create, view, update, and delete plates with automatic well generation
- **Location Management**: Manage carousel positions and special locations with grid visualization
- **Location Tracking**: Track plate movements with full history and occupancy validation
- **Grid View**: Visual carousel layout showing occupied/available positions

### REST API
- **Full CRUD Operations**: Complete API coverage for all web interface functionality
- **Location Management**: Create locations, move plates, track history via API
- **System Monitoring**: Health checks and comprehensive statistics
- **JSON Responses**: Consistent JSON API with error handling

## Quick Start

### Prerequisites
- Ruby 3.3.0+
- Rails 8.0+
- SQLite3 (development) or PostgreSQL (production)

### Installation
```bash
git clone <repository-url>
cd crystal-plates-db
bundle install
rails db:create db:migrate db:seed
```

### Running the Application
```bash
# Start the server
rails server

# Web interface available at: http://localhost:3000
# API base URL: http://localhost:3000/api/v1
```

## Usage

### Web Interface
1. **View Plates**: Navigate to `/plates` to see all plates
2. **Create Plate**: Click "New Plate" and enter a barcode
3. **Manage Locations**: Go to `/locations` for location management
4. **Grid View**: Use `/locations/grid` for visual carousel layout
5. **Move Plates**: Use the plate form to assign locations

### REST API
```bash
# Health check
curl http://localhost:3000/api/v1/health

# List all plates
curl http://localhost:3000/api/v1/plates

# Create a plate
curl -X POST http://localhost:3000/api/v1/plates \
  -H "Content-Type: application/json" \
  -d '{"plate": {"barcode": "PLATE001"}}'

# Move plate to location
curl -X POST http://localhost:3000/api/v1/plates/PLATE001/move_to_location \
  -H "Content-Type: application/json" \
  -d '{"location_id": 1, "moved_by": "user"}'

# Get system statistics
curl http://localhost:3000/api/v1/stats
```

## Testing

### Run All Tests
```bash
bundle exec rails test                    # All tests
bundle exec rails test test/models/       # Model tests only
bundle exec rails test test/controllers/  # Controller tests only
bundle exec rails test test/integration/  # Integration tests only
```

### API Testing
```bash
# Run API-specific tests
bundle exec rails test test/controllers/api/

# Demo API functionality
./bin/api_demo  # Requires jq and curl
```

## Documentation

- **API Documentation**: [API_DOCUMENTATION.md](API_DOCUMENTATION.md)
- **Testing Guide**: [TESTING.md](TESTING.md)
- **Test Summary**: [TEST_SUMMARY.md](TEST_SUMMARY.md)

## Architecture

### Models
- **Plate**: Core entity with barcode and wells
- **Location**: Carousel positions or special named locations
- **PlateLocation**: Junction table tracking movement history
- **Well**: Individual plate positions with content tracking

### Key Features
- **Location Validation**: Only one plate per location
- **Movement History**: Full audit trail of plate movements
- **Grid Visualization**: 10x20 carousel grid (carousel × hotel positions)
- **RESTful API**: Complete API coverage with consistent JSON responses

## Development

### Database Schema
```bash
rails db:create db:migrate    # Setup database
rails db:seed                 # Load sample data
rails db:reset                # Reset and reseed
```

### Code Quality
```bash
rubocop                       # Code linting
bundle exec rails test        # Test suite
```

## API Endpoints

### Plates
- `GET /api/v1/plates` - List all plates
- `POST /api/v1/plates` - Create plate
- `GET /api/v1/plates/:barcode` - Get plate details
- `PUT /api/v1/plates/:barcode` - Update plate
- `DELETE /api/v1/plates/:barcode` - Delete plate
- `POST /api/v1/plates/:barcode/move_to_location` - Move plate

### Locations
- `GET /api/v1/locations` - List all locations (with optional query parameters)
- `POST /api/v1/locations` - Create location
- `GET /api/v1/locations/:id` - Get location details
- `PUT /api/v1/locations/:id` - Update location
- `DELETE /api/v1/locations/:id` - Delete location

### Utilities
- `GET /api/v1/health` - System health check
- `GET /api/v1/stats` - System statistics

## Deployment

For production deployment instructions using GitHub Actions, see [DEPLOYMENT_GITHUB_ACTIONS.md](DEPLOYMENT_GITHUB_ACTIONS.md).

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License.
