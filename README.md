# Expose Private Port

A [Caddy](https://caddyserver.com/) reverse proxy for Railway that exposes a second port from a service on its own public domain.

Railway assigns one `.up.railway.app` domain per service. When a container exposes multiple ports (for example, an app on `3000` and an admin UI on `8080`), only one port can be attached to that public domain. Deploy this proxy as a separate service to give the second port its own public URL while forwarding traffic over Railway's private network.

## Overview

This project runs Caddy as a lightweight proxy service on Railway. It listens on the platform-assigned `PORT`, accepts public HTTPS traffic on a dedicated Railway domain, and forwards every request to a target service port reachable via `RAILWAY_PRIVATE_DOMAIN`.

Typical use case:

- **Main service** — port `3000` on `https://myapp.up.railway.app`
- **This proxy** — port `8080` on `https://myapp-admin.up.railway.app`

Both point at the same Railway service; the proxy reaches the second port through private networking.

## Architecture

```
Internet
   │
   ▼
┌─────────────────────────────┐
│  Proxy service (this repo)  │  ← public .up.railway.app domain #2
│  Caddy on $PORT             │
└──────────────┬──────────────┘
               │ Railway private network (IPv6)
               ▼
┌─────────────────────────────┐
│  Target service             │  ← public .up.railway.app domain #1
│  Container with 2+ ports    │
│  TARGET_PORT (e.g. 8080)    │
└─────────────────────────────┘
```

The proxy configuration lives in [`Caddyfile`](./Caddyfile). Runtime wiring is handled by [`entrypoint.sh`](./entrypoint.sh).

## Components

### Caddyfile

Defines global Railway-friendly settings (no admin API, no auto HTTPS, trusted private proxies) and a single `reverse_proxy` block that resolves the target through dynamic DNS (`dynamic a`) so replica scaling and private-network DNS updates are handled automatically.

### entrypoint.sh

Reads `TARGET_DOMAIN` and `TARGET_PORT` from the environment (or parses them from `TARGET_HOST` in `host:port` form) and starts Caddy.

### Dockerfile

Builds from the official `caddy:latest` image, formats the Caddyfile, and runs the entrypoint script.

## Deployment

### 1. Prepare the target service

The service you want to expose must:

- Listen on a **fixed port** for the second endpoint (set a `PORT` or additional port variable as needed).
- Bind to **`::`** (all interfaces) so it is reachable on Railway's IPv6-only private network.

Example start commands:

- **Gunicorn:** `gunicorn main:app -b [::]:${ADMIN_PORT:-8080}`
- **Uvicorn:** `uvicorn admin:app --host :: --port ${ADMIN_PORT:-8080}`
- **Hypercorn:** `hypercorn admin:app --bind [::]:${ADMIN_PORT:-8080}`
- **Express/Nest:** `app.listen(process.env.ADMIN_PORT || 8080, "::");`

The main public domain can continue to use the service's primary port as usual.

### 2. Deploy this proxy service

Create a new Railway service from this repository and set:

| Variable | Description | Example |
|----------|-------------|---------|
| `TARGET_DOMAIN` | Private hostname of the target service | `${{MyService.RAILWAY_PRIVATE_DOMAIN}}` |
| `TARGET_PORT` | Port to expose publicly | `8080` |

Use [reference variables](https://docs.railway.app/guides/variables#referencing-another-services-variable) to point at the service that owns the container:

```
TARGET_DOMAIN = ${{MyService.RAILWAY_PRIVATE_DOMAIN}}
TARGET_PORT = 8080
```

Alternatively, pass both in one variable:

```
TARGET_HOST = ${{MyService.RAILWAY_PRIVATE_DOMAIN}}:8080
```

### 3. Assign a public domain

Generate a public domain for **this proxy service** in the Railway dashboard. All paths and methods are forwarded unchanged to the target port.

## Style

No application UI is included. The proxy preserves request paths, query strings, headers, and WebSocket upgrades supported by Caddy's `reverse_proxy` directive.

## Test

After deployment:

1. Confirm the target service responds on the chosen port over the private network (check target service logs).
2. Open the proxy service's public URL and verify the expected response.
3. Inspect proxy logs in Railway for JSON access and runtime entries.

## Maintenance

- **Target unreachable:** Ensure the target binds to `::`, uses a fixed port, and `TARGET_DOMAIN` / `TARGET_PORT` reference the correct service.
- **502 / unhealthy upstream:** The Caddyfile includes passive health checks and retries for cold starts and replica wake-up; increase `lb_try_duration` in the Caddyfile if needed.
- **Wrong Host header:** The proxy sets `Host` to `{upstream_hostport}` for private-network upstreams; adjust `header_up` in the Caddyfile if your app expects a different host.

## Relevant documentation

- [Railway private networking](https://docs.railway.app/guides/private-networking)
- [Railway service variables](https://docs.railway.app/guides/variables)
- [Caddy reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Caddy dynamic upstreams](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#dynamic)

## License

See [LICENSE](./LICENSE).
