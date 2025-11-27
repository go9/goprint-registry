# GoPrint - Cloud Service Guide for Claude

## IMPORTANT: Read this before making changes to GoPrint

This document describes the structure and key components of the GoPrint Phoenix application located at `/Users/giovanniorlando/Sites/goprint_registry`.

## Related Repositories

This is part of a three-repository ecosystem:

1. **goprint** - Desktop application that runs on client machines
   - Electron app that manages local printers
   - Registers with this registry to receive print jobs
   - Exposes local API on port 4000 for receiving print jobs
   - Located at: `/Users/giovanniorlando/Sites/goprint`

2. **goprint_registry** (this repo) - Cloud registry service
   - Phoenix/Elixir web application
   - Manages desktop client registrations
   - Routes print jobs from third-party apps to desktop clients
   - Provides API for third parties to send print jobs
   - Located at: `/Users/giovanniorlando/Sites/goprint_registry`

3. **enventory** - Example third-party application
   - Phoenix/Elixir inventory management system
   - Integrates with this registry to send print jobs
   - Uses GoPrint for barcode and label printing
   - Located at: `/Users/giovanniorlando/Sites/enventory`

## Key Components

### Desktop Client Management
- Handles registration of desktop GoPrint clients
- Maintains heartbeat/connection status
- Routes print jobs to appropriate clients

### API Endpoints
- `/api/clients/register` - Desktop clients register here
- `/api/clients/:id/heartbeat` - Keep-alive for desktop clients
- `/api/print_jobs/file` - Third parties submit print jobs here
- `/api/clients/:id/printers` - Get available printers for a client

### Authentication
- API key authentication for third-party applications
- Client ID/secret for desktop client authentication

## Development Setup

1. Start the Phoenix server:
   ```bash
   cd /Users/giovanniorlando/Sites/goprint_registry
   mix phx.server
   ```

2. The registry runs on:
   - Development: `http://localhost:4002`
   - Production: `https://goprint.dev`

## Testing the Integration

1. Start the registry: `mix phx.server`
2. Start the desktop app: `cd ../goprint && npm start`
3. Desktop app will auto-register with the registry
4. Start enventory: `cd ../enventory && mix phx.server`
5. Use enventory's bulk upload feature to test barcode printing