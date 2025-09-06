#!/bin/bash

# GoPrint Registry API Test Script

BASE_URL="http://localhost:4002/api"
API_KEY="test-developer-key-123"
CLIENT_ID="desktop_test_123"

echo "Testing GoPrint Registry API..."
echo "================================"

# Test status endpoint
echo -e "\n1. Testing status endpoint..."
curl -s "${BASE_URL}/status" | jq '.'

# Test listing connected clients (should be empty initially)
echo -e "\n2. Testing list clients (requires auth)..."
curl -s -H "Authorization: Bearer ${API_KEY}" \
  "${BASE_URL}/clients" | jq '.'

# Test listing jobs (should be empty initially)
echo -e "\n3. Testing list jobs..."
curl -s -H "Authorization: Bearer ${API_KEY}" \
  "${BASE_URL}/jobs" | jq '.'

# Test submitting a print job (will fail since no desktop client is connected)
echo -e "\n4. Testing print job submission (expected to fail - no client connected)..."
curl -s -X POST \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "'"${CLIENT_ID}"'",
    "printer_id": "printer_001",
    "content": "<h1>Test Print Job</h1><p>This is a test print job from the API.</p>",
    "options": {
      "copies": 1,
      "color": true
    }
  }' \
  "${BASE_URL}/print" | jq '.'

# Test bulk print endpoint
echo -e "\n5. Testing bulk print endpoint..."
curl -s -X POST \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "jobs": [
      {
        "client_id": "'"${CLIENT_ID}"'",
        "printer_id": "printer_001",
        "content": "<h1>Bulk Job 1</h1>"
      },
      {
        "client_id": "'"${CLIENT_ID}"'",
        "printer_id": "printer_002",
        "content": "<h1>Bulk Job 2</h1>"
      }
    ]
  }' \
  "${BASE_URL}/print/bulk" | jq '.'

echo -e "\n================================"
echo "API test complete!"
echo ""
echo "Note: Print jobs will fail since no desktop client is connected."
echo "To test with a real desktop client:"
echo "1. Start the desktop app (goprint_tauri) with CloudClient enabled"
echo "2. The desktop app will connect via WebSocket to this registry"
echo "3. Run this script again to send print jobs to the connected desktop"