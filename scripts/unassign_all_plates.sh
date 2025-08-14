#!/bin/bash

# Script to unassign all plates from their locations
# Usage: ./unassign_all_plates.sh [server_url]

# Default server URL - change this to match your environment
SERVER_URL="${1:-http://aicdocker.liv.ac.uk:3000}"

echo "🔍 Fetching all plate barcodes from $SERVER_URL..."

# Get all plates and extract barcodes using jq
BARCODES=$(curl -s "$SERVER_URL/api/v1/plates" \
  -H "Content-Type: application/json" | \
  jq -r '.data[].barcode' 2>/dev/null)

# Check if we got any barcodes
if [ -z "$BARCODES" ]; then
  echo "❌ No plates found or error fetching plates"
  echo "   Make sure the server is running and accessible at $SERVER_URL"
  exit 1
fi

# Count total plates
TOTAL=$(echo "$BARCODES" | wc -l)
echo "📦 Found $TOTAL plates to process"

# Counter for progress
COUNT=0
SUCCESS_COUNT=0
ERROR_COUNT=0

echo ""
echo "🚀 Starting unassignment process..."

# Process each barcode
while IFS= read -r barcode; do
  if [ -n "$barcode" ]; then
    COUNT=$((COUNT + 1))
    echo -n "[$COUNT/$TOTAL] Unassigning plate $barcode... "
    
    # Make the unassign request
    RESPONSE=$(curl -s -w "%{http_code}" \
      -X POST "$SERVER_URL/api/v1/plates/$barcode/unassign_location" \
      -H "Content-Type: application/json")
    
    # Extract HTTP status code (last 3 characters)
    HTTP_CODE="${RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "200" ]; then
      echo "✅ Success"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo "❌ Failed (HTTP $HTTP_CODE)"
      ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
  fi
done <<< "$BARCODES"

echo ""
echo "📊 Summary:"
echo "   Total plates: $TOTAL"
echo "   Successfully unassigned: $SUCCESS_COUNT"
echo "   Errors: $ERROR_COUNT"

if [ $ERROR_COUNT -eq 0 ]; then
  echo "🎉 All plates successfully unassigned!"
else
  echo "⚠️  Some plates failed to unassign. Check server logs for details."
fi
