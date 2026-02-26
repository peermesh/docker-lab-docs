# Extending Docker Lab

> Learn how to add your own services, build custom profiles, and create reusable modules that integrate seamlessly with the Docker Lab foundation.

## Overview

Docker Lab is designed to be extended. The foundation stack gives you a reverse proxy, secret management, network isolation, and health-checked startup ordering -- but the real value comes when you deploy your own applications on top of it. Think of Docker Lab as a well-organized workshop: the workbench, power tools, and safety equipment are already set up. Your job is to bring your project to the bench and plug it in.

This chapter walks you through extending Docker Lab at every level. You will add a custom service from scratch, create a reusable profile, and learn the module system that ties everything together. By the end, you will understand the patterns that keep Docker Lab extensible without sacrificing the security and reliability of the foundation.

Why does this matter? Every self-hosted application you deploy follows the same integration pattern. Learn it once, and you can deploy anything -- a blog, a chat server, an API backend, a machine learning pipeline -- with consistent security, routing, and resource management.

## The Four-Tier Extension Model

Before adding your first service, you need to understand where it fits. Docker Lab organizes everything into four tiers, each building on the one below it.

The following diagram shows how the four tiers relate to each other:

```mermaid
flowchart TB
    Tier4["Tier 4: Services -- Custom integrations with module manifests"]
    Tier3["Tier 3: Examples -- Application deployments"]
    Tier2["Tier 2: Profiles -- Supporting infrastructure like databases and caches"]
    Tier1["Tier 1: Foundation -- Traefik, socket proxy, networks, secrets"]

    Tier4 --> Tier3
    Tier3 --> Tier2
    Tier2 --> Tier1
```

Each tier has a specific purpose:

- **Tier 1 (Foundation)** provides Traefik, the socket proxy, the four-network topology, and secret management. You never modify this tier -- you build on top of it.
- **Tier 2 (Profiles)** adds supporting infrastructure like PostgreSQL, MySQL, Redis, and MinIO. These are shared services that multiple applications can use.
- **Tier 3 (Examples)** contains application deployments. Each example lives in its own directory with its own compose file and documentation. This is where most custom services land.
- **Tier 4 (Services)** is for deeply integrated components that register with the dashboard, declare module manifests, and participate in the event system.

Most of the time, you will work at Tier 3. If your application needs a database that Docker Lab does not include yet, you will create a Tier 2 profile. If you are building a full module with dashboard integration, you are working at Tier 4.

## Tutorial: Add Your First Custom Service

We will walk through adding a hypothetical internal wiki called "TeamNotes" -- a Node.js application that needs PostgreSQL, serves content over HTTPS, and should be protected by authentication on its admin pages. This is a realistic scenario that exercises every integration point.

### Step 1: Create the Example Directory

Every custom application lives in the `examples/` directory. Start by creating a directory for your service and copying the template.

```bash
$ mkdir -p examples/teamnotes
$ cp examples/_template/docker-compose.template.yml examples/teamnotes/docker-compose.teamnotes.yml
$ cp examples/_template/README.md examples/teamnotes/README.md
$ cp examples/_template/.env.example examples/teamnotes/.env.example
```

Your directory now looks like this:

```text
examples/teamnotes/
  docker-compose.teamnotes.yml
  README.md
  .env.example
```

### Step 2: Configure the Compose File

Open `docker-compose.teamnotes.yml` and replace the template placeholders. Here is the complete, working configuration:

**File: `examples/teamnotes/docker-compose.teamnotes.yml`**

```yaml
# TeamNotes Internal Wiki
#
# Prerequisites:
#   - Foundation running (docker compose up -d)
#   - PostgreSQL profile enabled
#
# Deploy:
#   docker compose -f docker-compose.yml \
#     -f profiles/postgresql/docker-compose.postgresql.yml \
#     -f examples/teamnotes/docker-compose.teamnotes.yml \
#     up -d

x-teamnotes-healthcheck: &teamnotes-healthcheck
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s

x-teamnotes-logging: &teamnotes-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

services:
  teamnotes:
    image: example/teamnotes:2.4.1
    container_name: pmdl_teamnotes
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://teamnotes:${TEAMNOTES_DB_PASSWORD}@postgres:5432/teamnotes
      APP_URL: https://wiki.${DOMAIN}
      APP_SECRET_FILE: /run/secrets/teamnotes_secret
    secrets:
      - teamnotes_db_password
      - teamnotes_secret
    volumes:
      - pmdl_teamnotes_data:/app/data
      - pmdl_teamnotes_uploads:/app/uploads
    networks:
      - proxy-external
      - db-internal
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    healthcheck:
      <<: *teamnotes-healthcheck
      test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:3000/health || exit 1"]
    restart: unless-stopped
    logging:
      <<: *teamnotes-logging
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.teamnotes.rule=Host(`wiki.${DOMAIN}`)"
      - "traefik.http.routers.teamnotes.entrypoints=websecure"
      - "traefik.http.routers.teamnotes.tls=true"
      - "traefik.http.routers.teamnotes.tls.certresolver=letsencrypt"
      - "traefik.http.routers.teamnotes.service=teamnotes"
      - "traefik.http.routers.teamnotes.priority=10"
      - "traefik.http.routers.teamnotes-admin.rule=Host(`wiki.${DOMAIN}`) && PathPrefix(`/admin`)"
      - "traefik.http.routers.teamnotes-admin.entrypoints=websecure"
      - "traefik.http.routers.teamnotes-admin.tls=true"
      - "traefik.http.routers.teamnotes-admin.tls.certresolver=letsencrypt"
      - "traefik.http.routers.teamnotes-admin.middlewares=authelia@file"
      - "traefik.http.routers.teamnotes-admin.service=teamnotes"
      - "traefik.http.routers.teamnotes-admin.priority=100"
      - "traefik.http.services.teamnotes.loadbalancer.server.port=3000"

secrets:
  teamnotes_db_password:
    file: ./secrets/teamnotes_db_password
  teamnotes_secret:
    file: ./secrets/teamnotes_secret

volumes:
  pmdl_teamnotes_data:
    driver: local
  pmdl_teamnotes_uploads:
    driver: local

networks:
  proxy-external:
    external: true
    name: pmdl_proxy-external
  db-internal:
    external: true
    name: pmdl_db-internal
```

There is a lot happening in this file, so let us break down each section.

### Step 3: Understand the Integration Points

The following diagram shows how your custom service connects to the foundation stack:

```mermaid
flowchart TB
    Internet["Internet"]
    Traefik["Traefik Reverse Proxy"]
    TeamNotes["TeamNotes App"]
    Postgres["PostgreSQL"]
    SocketProxy["Socket Proxy"]
    Docker["Docker Engine"]

    Internet -->|"HTTPS request"| Traefik
    Traefik -->|"proxy-external network"| TeamNotes
    TeamNotes -->|"db-internal network"| Postgres
    Traefik -->|"management network"| SocketProxy
    SocketProxy -->|"Docker socket"| Docker
```

Your service connects to the foundation through three mechanisms:

**Networks** determine which services can talk to each other. TeamNotes joins two networks: `proxy-external` so Traefik can route traffic to it, and `db-internal` so it can reach PostgreSQL. It does not join the `management` network because it has no reason to talk to the Docker socket proxy.

**Traefik labels** tell the reverse proxy how to route traffic. The labels declare two routers: one for public access to the wiki and one for the admin section that requires authentication through Authelia. The `priority` values ensure the more specific admin route matches first.

**Secrets** are file-based credentials mounted into the container at `/run/secrets/`. This approach keeps passwords out of environment variables (which can leak through process listings and debug endpoints) and out of compose files (which might be committed to version control).

### Step 4: Generate Secrets

Every application needs its own secret files. Generate them before the first deployment.

```bash
$ openssl rand -base64 32 > secrets/teamnotes_db_password
$ openssl rand -base64 32 > secrets/teamnotes_secret
$ chmod 600 secrets/teamnotes_db_password secrets/teamnotes_secret
```

The `chmod 600` command restricts the files so only the file owner can read them. Docker Lab enforces this permission model across all secret files.

### Step 5: Initialize the Database

PostgreSQL needs to know about your application's database and user before the application starts. Add an initialization block to the PostgreSQL profile's init script.

**File: `profiles/postgresql/init-scripts/01-init-databases.sh`** (append to existing file)

```bash
TEAMNOTES_PASSWORD=$(cat /run/secrets/teamnotes_db_password 2>/dev/null || echo "")
if [ -n "$TEAMNOTES_PASSWORD" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE teamnotes;
        CREATE USER teamnotes WITH PASSWORD '$TEAMNOTES_PASSWORD';
        GRANT ALL PRIVILEGES ON DATABASE teamnotes TO teamnotes;
    EOSQL
fi
```

This script runs only once -- when the PostgreSQL container initializes for the first time. The `if` guard ensures it does not fail if the secret file is not present (for example, if PostgreSQL is being used by other services that do not need TeamNotes).

### Step 6: Deploy and Validate

Start the full stack with your new service included:

```bash
$ docker compose \
    -f docker-compose.yml \
    -f profiles/postgresql/docker-compose.postgresql.yml \
    -f examples/teamnotes/docker-compose.teamnotes.yml \
    up -d
```

Validate the deployment:

```bash
$ docker compose ps
NAME              STATUS           PORTS
traefik           running (healthy)  80/tcp, 443/tcp
socket-proxy      running (healthy)  2375/tcp
postgres          running (healthy)  5432/tcp
teamnotes         running (healthy)  3000/tcp

$ curl -I https://wiki.yourdomain.com
HTTP/2 200

$ curl -I https://wiki.yourdomain.com/admin
HTTP/2 302
Location: https://auth.yourdomain.com/...
```

The admin route returns a 302 redirect to Authelia, confirming that authentication protection is active.

## Creating a Custom Profile

Profiles live at Tier 2 and provide shared infrastructure that multiple applications can use. While Docker Lab ships with profiles for PostgreSQL, MySQL, MongoDB, Redis, and MinIO, you may need something else -- a message queue like RabbitMQ, a search engine like Meilisearch, or a time-series database like InfluxDB.

### Profile Directory Structure

Every profile follows a standard layout:

```text
profiles/my-service/
  PROFILE-SPEC.md
  docker-compose.my-service.yml
  init-scripts/
  backup-scripts/
  healthcheck-scripts/
```

Start by copying the profile template:

```bash
$ cp -r profiles/_template profiles/rabbitmq
```

### Writing the Compose File

A profile compose file defines the service, its health check, resource limits, and network connections. Here is a complete RabbitMQ profile:

**File: `profiles/rabbitmq/docker-compose.rabbitmq.yml`**

```yaml
services:
  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    container_name: pmdl_rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER_FILE: /run/secrets/rabbitmq_user
      RABBITMQ_DEFAULT_PASS_FILE: /run/secrets/rabbitmq_password
    secrets:
      - rabbitmq_user
      - rabbitmq_password
    volumes:
      - pmdl_rabbitmq_data:/var/lib/rabbitmq
    networks:
      - db-internal
    deploy:
      resources:
        limits:
          memory: ${RABBITMQ_MEMORY_LIMIT:-512M}
        reservations:
          memory: ${RABBITMQ_MEMORY_RESERVATION:-256M}
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "check_port_connectivity"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    restart: unless-stopped

secrets:
  rabbitmq_user:
    file: ./secrets/rabbitmq_user
  rabbitmq_password:
    file: ./secrets/rabbitmq_password

volumes:
  pmdl_rabbitmq_data:
    driver: local

networks:
  db-internal:
    external: true
    name: pmdl_db-internal
```

Notice the patterns that make this a well-behaved profile:

- **Secrets via files** -- credentials use `_FILE` suffixes, never plain text in environment variables
- **Resource limits with defaults** -- the `${RABBITMQ_MEMORY_LIMIT:-512M}` syntax lets operators override limits without editing the compose file
- **Health check** -- RabbitMQ provides a built-in diagnostic command; use it instead of a generic TCP check
- **Network isolation** -- RabbitMQ joins only `db-internal` because no external traffic should reach it directly
- **Named volumes with prefix** -- the `pmdl_` prefix prevents naming collisions with other Docker projects on the same host

### Testing Your Profile

Before deploying, validate the compose configuration:

```bash
$ docker compose \
    -f docker-compose.yml \
    -f profiles/rabbitmq/docker-compose.rabbitmq.yml \
    config
```

This command merges the compose files and prints the resolved configuration. If there are syntax errors, missing network references, or other problems, they appear here -- not during deployment. Always run `config` before `up`.

## The Example Application Pattern

Docker Lab uses a deliberate pattern for organizing example applications. Understanding this pattern helps you create services that are consistent with the rest of the project and easy for others to use.

### Why Separate Compose Files?

You might wonder why each application gets its own compose file instead of being added to the main `docker-compose.yml`. The reason is lifecycle separation. Foundation infrastructure (Traefik, socket proxy) has a different change frequency than your applications. You update your blog software weekly; you update Traefik once a quarter. Keeping them in separate files means you can:

- Start and stop applications independently
- Update one application without touching others
- Share application configurations with other Docker Lab users
- Test applications in isolation

The following diagram shows how compose files extend and override each other:

```mermaid
flowchart TB
    Base["docker-compose.yml -- Foundation services, networks, secrets"]
    Profile["profiles/postgresql/docker-compose.postgresql.yml -- Database service"]
    App["examples/teamnotes/docker-compose.teamnotes.yml -- Application service"]

    Base -->|"provides networks"| Profile
    Base -->|"provides networks"| App
    Profile -->|"provides database"| App
```

When you run `docker compose -f` with multiple files, Docker merges them left to right. The foundation file defines the networks, the profile file adds a database on those networks, and the application file adds your service on the same networks with a dependency on the database.

### Example Directory Checklist

Every example directory should contain these files:

| File | Purpose |
|------|---------|
| `docker-compose.<name>.yml` | Complete compose configuration for the service |
| `README.md` | Setup instructions, prerequisites, configuration reference |
| `.env.example` | Template environment file with all required variables |
| `secrets-required.txt` | List of secret files that must be created before deployment |

### Using the COMPOSE_FILE Variable

Typing long `-f` chains gets tedious. Docker Compose supports the `COMPOSE_FILE` environment variable as a shortcut:

```bash
$ export COMPOSE_FILE=docker-compose.yml:profiles/postgresql/docker-compose.postgresql.yml:examples/teamnotes/docker-compose.teamnotes.yml
$ docker compose up -d
$ docker compose ps
$ docker compose logs teamnotes
```

All subsequent `docker compose` commands in that shell session use the same set of files. This is especially useful in `.env` files for persistent configuration:

**File: `.env`**

```bash
COMPOSE_FILE=docker-compose.yml:profiles/postgresql/docker-compose.postgresql.yml:examples/teamnotes/docker-compose.teamnotes.yml
DOMAIN=example.com
```

## Integration Testing Your Custom Service

Deploying is only half the work. You need to verify that your service integrates correctly with the foundation stack.

### Compose Configuration Validation

Always start by validating the merged compose configuration:

```bash
$ docker compose -f docker-compose.yml \
    -f profiles/postgresql/docker-compose.postgresql.yml \
    -f examples/teamnotes/docker-compose.teamnotes.yml \
    config -q
```

The `-q` flag suppresses output on success. If this command exits with code 0, your compose files merge correctly. If it exits with an error, the error message tells you exactly what is wrong.

### Health Check Verification

After deployment, confirm that all services report healthy status:

```bash
$ docker compose ps --format "table {{.Name}}\t{{.Status}}"
NAME              STATUS
pmdl_traefik      running (healthy)
pmdl_socket-proxy running (healthy)
pmdl_postgres     running (healthy)
pmdl_teamnotes    running (healthy)
```

If a service shows "starting" for more than its `start_period`, check its logs for errors.

### Network Connectivity Tests

Verify that your service can reach its dependencies and that isolation is enforced:

```bash
$ docker compose exec teamnotes nc -zv postgres 5432
Connection to postgres 5432 port [tcp/postgresql] succeeded!

$ docker compose exec teamnotes wget -q --spider http://127.0.0.1:3000/health
```

### TLS Certificate Check

Confirm that Traefik has provisioned a valid certificate for your subdomain:

```bash
$ echo | openssl s_client -connect wiki.yourdomain.com:443 2>/dev/null \
    | openssl x509 -noout -dates
notBefore=Feb 25 00:00:00 2026 GMT
notAfter=May 26 00:00:00 2026 GMT
```

### Resource Limit Verification

Check that container memory limits are enforced:

```bash
$ docker stats --no-stream pmdl_teamnotes
CONTAINER         CPU %   MEM USAGE / LIMIT   MEM %
pmdl_teamnotes    0.15%   87MiB / 512MiB      17.00%
```

The "LIMIT" column should match the `deploy.resources.limits.memory` value from your compose file.

## Best Practices for Service Isolation and Security

Docker Lab's four-network topology exists to enforce the principle of least privilege. Every service should connect only to the networks it needs and nothing more.

### Network Selection Guide

| Your service needs to... | Connect to this network |
|--------------------------|------------------------|
| Receive traffic from the internet via Traefik | `proxy-external` |
| Communicate with other internal services | `proxy-internal` |
| Access a database (PostgreSQL, MySQL, MongoDB) | `db-internal` |
| Talk to the Docker socket proxy (rare) | `management` |

Most applications need only `proxy-external` and `db-internal`. If your service does not serve web traffic (for example, a background worker), it may only need `db-internal`.

### Secret Hygiene

Follow these rules for every service you add:

1. **Never hardcode credentials** in compose files, Dockerfiles, or environment variable defaults
2. **Use the `_FILE` suffix pattern** when the application supports it -- this reads the secret from a mounted file instead of an environment variable
3. **Generate unique secrets per service** -- do not reuse the PostgreSQL root password for your application
4. **Set file permissions to 600** on every secret file so only the owner can read it

### Resource Limits Are Not Optional

Every service must declare memory limits. A service without limits can consume all available memory on the host, crashing every other service. Use these guidelines for sizing:

| Application Type | Memory Limit | Memory Reservation |
|------------------|--------------|--------------------|
| Static site generator | 128M | 64M |
| Node.js application | 256-512M | 128-256M |
| Python/Django application | 256-512M | 128-256M |
| Java/Kotlin application | 512M-2G | 256M-1G |
| PHP application | 256-512M | 128-256M |

### Health Checks Are Not Optional

Every service must declare a health check. Without one, Docker cannot determine startup ordering, and dependent services may start before their dependencies are ready. Follow these rules:

- **Use IPv4 explicitly** -- `http://127.0.0.1:3000/health` instead of `http://localhost:3000/health` because localhost may resolve to IPv6 on some systems
- **Match the health check tool to the base image** -- Alpine images include `wget` but not `curl`; Debian images include `curl`
- **Set a generous `start_period`** for applications that take time to initialize (database migrations, asset compilation)

## The Module System: Deep Integration

If your service needs to register with the Docker Lab dashboard, declare dependencies on other modules, or participate in the event system, you are building a Tier 4 module. Modules go beyond simple compose file integration -- they include a JSON manifest that describes the module's capabilities, requirements, and lifecycle.

### Module Directory Structure

```text
modules/my-module/
  module.json
  docker-compose.yml
  README.md
  hooks/
    install.sh
    start.sh
    stop.sh
    health.sh
  dashboard/
    StatusWidget.html
```

### Creating a Module from the Template

Docker Lab provides a starter template:

```bash
$ cp -r foundation/templates/module-template modules/my-module
$ cd modules/my-module
```

### The Module Manifest

The `module.json` file is the contract between your module and the foundation. Here is a minimal manifest:

```json
{
  "id": "my-module",
  "version": "1.0.0",
  "name": "My Custom Module",
  "description": "A module that does useful things",
  "foundation": {
    "minVersion": "1.0.0"
  },
  "requires": {
    "connections": [
      {
        "type": "database",
        "providers": ["postgres"],
        "required": true,
        "alias": "my-module-db"
      }
    ]
  },
  "provides": {
    "events": [
      "my-module.data.imported",
      "my-module.data.exported"
    ]
  },
  "lifecycle": {
    "install": "./hooks/install.sh",
    "start": "./hooks/start.sh",
    "stop": "./hooks/stop.sh",
    "health": "./hooks/health.sh"
  },
  "dashboard": {
    "displayName": "My Module",
    "icon": "puzzle",
    "routes": [
      {
        "path": "/my-module",
        "component": "./dashboard/StatusWidget.html",
        "nav": {
          "label": "My Module",
          "icon": "puzzle",
          "order": 50
        }
      }
    ]
  }
}
```

The manifest declares three things:

- **Requirements** -- the module needs a PostgreSQL database connection
- **Capabilities** -- the module emits two events that other modules can listen for
- **Dashboard registration** -- the module appears in the dashboard navigation with a status widget

### Module Compose File Pattern

Module compose files use `extends` to inherit resource limits from foundation base services:

```yaml
services:
  my-module-app:
    extends:
      file: ../../docker-compose.base.yml
      service: _service-standard
    image: my-org/my-module:1.0.0
    container_name: pmdl_my-module
    environment:
      - MY_MODULE_DB_URL=postgresql://mymod:${MY_MODULE_DB_PASSWORD}@postgres:5432/mymod
    volumes:
      - my-module-data:/data
    healthcheck:
      test: ["CMD", "sh", "-c", "wget -q --spider http://127.0.0.1:8080/health || exit 0"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - proxy-external
      - db-internal
```

The `extends` directive pulls in resource limits, logging configuration, and other base settings from the foundation. This keeps your compose file focused on what makes your module unique.

### Activating a Module

Include the module compose file alongside the root stack:

```bash
$ docker compose -f docker-compose.yml \
    -f profiles/postgresql/docker-compose.postgresql.yml \
    -f modules/my-module/docker-compose.yml \
    up -d
```

## Common Gotchas

**Network name mismatch.** When referencing foundation networks from a separate compose file, you must use the full prefixed name. The compose file declares `proxy-external` as a service network alias, but the actual Docker network name is `pmdl_proxy-external`. Always include the `name` field in your network declaration:

```yaml
networks:
  proxy-external:
    external: true
    name: pmdl_proxy-external
```

**Healthcheck uses curl on Alpine image.** Alpine-based images do not include `curl` by default. Use `wget` instead:

```yaml
# Wrong -- fails on Alpine
test: ["CMD-SHELL", "curl -f http://127.0.0.1:3000/health || exit 1"]

# Correct -- works on Alpine
test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:3000/health || exit 1"]
```

**Forgot to create secret files.** If a compose file references a secret file that does not exist, `docker compose up` fails with a cryptic error about missing paths. Always generate secrets before the first deployment and verify they exist:

```bash
$ ls -la secrets/teamnotes_*
-rw------- 1 deploy deploy 44 Feb 25 10:00 secrets/teamnotes_db_password
-rw------- 1 deploy deploy 44 Feb 25 10:00 secrets/teamnotes_secret
```

**Database init script runs only once.** PostgreSQL's init scripts execute only when the data directory is empty (first container start). If you add a new application after PostgreSQL is already running, you must create the database manually:

```bash
$ docker compose exec postgres psql -U postgres -c "CREATE DATABASE teamnotes;"
$ docker compose exec postgres psql -U postgres -c "CREATE USER teamnotes WITH PASSWORD 'your-password';"
$ docker compose exec postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE teamnotes TO teamnotes;"
```

**Resource limit not enforced.** If `docker stats` shows no memory limit, your compose file's `deploy.resources` section may not be indented correctly. The `deploy` key must be at the same level as `image` and `environment`, not nested inside another key.

## Key Takeaways

- Every custom service follows the same pattern: create a directory in `examples/`, write a compose file that references foundation networks, add Traefik labels for routing, and generate secret files for credentials.
- Profiles provide reusable infrastructure (databases, caches, queues) at Tier 2. Create one when multiple applications need the same backing service.
- Modules at Tier 4 add dashboard registration, lifecycle hooks, and event declarations for deeply integrated services.
- Always validate your compose configuration with `docker compose config` before deploying.
- Enforce network isolation, resource limits, health checks, and file-based secrets on every service you add. These are not optional -- they are the patterns that keep Docker Lab reliable.

## Next Steps

Now that you know how to extend Docker Lab with your own services, the [Use Cases](./use-cases.md) chapter shows real-world deployment scenarios. You will see how teams combine foundation services, profiles, and custom applications to build complete self-hosted platforms -- from a personal blog with analytics to a multi-tenant SaaS stack with federated identity.
