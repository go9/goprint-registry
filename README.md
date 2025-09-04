# GoPrint Registry

A lightweight service discovery registry for GoPrint - the desktop print service that enables silent printing from web applications.

## Overview

GoPrint Registry allows GoPrint desktop clients to register themselves and be discovered by web applications without complex network configuration. It provides:

- 🌐 **Service Discovery** - Web apps can find GoPrint instances using API keys
- 🔄 **Auto-updating** - GoPrint clients update their IP when it changes  
- ⏱️ **TTL Management** - Automatic cleanup of stale registrations
- 🎨 **Landing Page** - Beautiful marketing page for GoPrint

## Architecture

```
GoPrint Desktop → Registers (API key + IP) → Registry
                                                ↓
Web Application → Lookup (API key) → Gets IP → Direct connection to GoPrint
```

## API Endpoints

### Register a GoPrint Instance
```bash
POST /api/register
Content-Type: application/json

{
  "api_key": "gp_your_api_key",
  "ip": "192.168.1.100",
  "port": 9377,
  "name": "Office Printer"
}
```

### Lookup a GoPrint Instance
```bash
GET /api/lookup/gp_your_api_key

Response:
{
  "success": true,
  "service": {
    "ip": "192.168.1.100",
    "port": 9377,
    "name": "Office Printer",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

### Check Registry Status
```bash
GET /api/status

Response:
{
  "active_services": 42,
  "ttl": 300,
  "server_time": "2024-01-15T10:30:00Z"
}
```

## Local Development

### Prerequisites
- Elixir 1.14+
- Phoenix 1.7+
- Node.js 18+

### Setup
```bash
# Install dependencies
mix deps.get

# Start Phoenix server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) to see the landing page.

## Deployment to Fly.io

### Initial Setup
```bash
# Install Fly CLI
brew install flyctl

# Login to Fly
fly auth login

# Create app
fly launch --name goprint-registry

# Deploy
fly deploy
```

### Configuration
The service runs perfectly on minimal resources:
- 1 shared CPU
- 256MB RAM
- No persistent storage needed (uses in-memory ETS)

## How It Works

1. **GoPrint Desktop App** sends a heartbeat every 30 seconds with its API key and current local IP
2. **Registry** stores the mapping in ETS with a 5-minute TTL
3. **Web Applications** query the registry using the API key to find GoPrint's IP
4. **Direct Connection** is established between the web app and GoPrint (no proxy)

## Benefits

- ✅ No DNS configuration required
- ✅ Works behind NAT/firewalls (on same network)
- ✅ No proxy overhead or liability
- ✅ Automatic IP updates when network changes
- ✅ Simple API key authentication

## License

MIT License - See LICENSE file for details

## Related Projects

- [GoPrint](https://github.com/go9/goprint) - Desktop print service for Mac
- [Enventory](https://github.com/go9/enventory) - Inventory management system with GoPrint integration