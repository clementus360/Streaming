# Production Deployment Guide - Streaming Platform

## Overview

This guide covers deploying the entire streaming platform on a single VM using Docker Compose with advanced production optimizations.

### What's Included

**Phase 1 - Unified Compose Setup** ✅
- Single `docker-compose.yml` with all 6 services
- Consolidated Redis (1 instance vs 3)
- Single Postgres database
- Proper dependency ordering
- Health checks for each service

**Phase 2 - Production Optimizations** ✅
- Port optimization (only expose 1935 & 8081)
- Resource limits per service
- Optional Nginx reverse proxy (HTTPS)
- Monitoring stack (Prometheus + Grafana)
- Security hardening guide
- Comprehensive environment configuration

## Architecture

```
┌─────────────────────────────────────────────────────┐
│           STREAMING PLATFORM (Single VM)            │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │     External Interfaces (Public, Exposed)   │   │
│  │                                             │   │
│  │  Port 1935: RTMP Ingest (from broadcasters) │   │
│  │  Port 8081: HTTP HLS (to viewers)           │   │
│  │  Port 80/443: Nginx (optional, HTTPS)       │   │
│  │                                             │   │
│  └────────────────────────┬────────────────────┘   │
│                           │                        │
│  ┌────────────────────────▼────────────────────┐   │
│  │   Docker Bridge Network (streaming_network) │   │
│  │   (All service communication is internal)   │   │
│  │                                             │   │
│  │  ┌──────────────┐      ┌──────────────┐    │   │
│  │  │ Ingest       │      │ Distribution │    │   │
│  │  │ (RTMP in)    │      │ (HLS out)    │    │   │
│  │  └──────┬───────┘      └──────┬───────┘    │   │
│  │         │                     │             │   │
│  │         └──────────┬──────────┘             │   │
│  │                    │                       │   │
│  │                    ▼                       │   │
│  │  ┌──────────────────────────────────┐     │   │
│  │  │   Stream Service                 │     │   │
│  │  │   (Orchestrator/Coordinator)     │     │   │
│  │  │   Manages lifecycle              │     │   │
│  │  └────────────────┬─────────────────┘     │   │
│  │                   │                       │   │
│  │         ┌─────────┼────────┐              │   │
│  │         ▼         ▼        ▼              │   │
│  │  ┌─────────┐ ┌────────┐ ┌──────────┐    │   │
│  │  │Auth     │ │ DB     │ │Processing│   │   │
│  │  │(JWT)    │ │Service │ │(FFmpeg)  │   │   │
│  │  └─────────┘ └───┬────┘ └──────────┘    │   │
│  │                  │                      │   │
│  │         ┌────────▼────────┐             │   │
│  │         ▼                 ▼             │   │
│  │  ┌──────────────┐ ┌──────────────┐    │   │
│  │  │ Postgres DB  │ │ Redis Cache  │    │   │
│  │  │ (1 instance) │ │ (1 instance) │    │   │
│  │  └──────────────┘ └──────────────┘    │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  Optional Addons (docker-compose.ADDON.yml):   │
│  - Nginx reverse proxy (docker-compose.nginx.yml) │
│  - Monitoring (docker-compose.monitoring.yml)    │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Quick Start

### 1. Prerequisites

```bash
# Install Docker & Docker Compose
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Install FFmpeg (required for processing service)
sudo apt-get install ffmpeg

# Start Docker daemon
sudo systemctl start docker
sudo systemctl enable docker

# Verify
docker --version
docker-compose --version
ffmpeg -version
```

### 2. Prepare Directory Structure

```bash
cd /path/to/Streaming

# Verify all service directories exist
ls -la go_auth go_database go_ingest go_stream go_processing go_distribution
```

### 3. Generate/Prepare Certificates

```bash
# If you don't have certificates:
cd security
./generate.sh
cd ..

# If you have existing certificates:
cp your/certs/* ./certs/

# Verify:
ls -la certs/
# Should show: ca-cert.pem, *-cert.pem, *-key.pem
```

### 4. Configure Environment

```bash
# Copy template
cp .env.production .env.prod

# Edit with your production values
# CRITICAL: Change all CHANGE_ME_* values
nano .env.prod

# Required changes:
# - POSTGRES_PASSWORD (strong, 32+ chars)
# - JWT_SECRET (strong, 32+ chars)
# - BASE_URL (your domain)
# - RESEND_KEY (if using email)
# - SENDER_EMAIL
# - FFMPEG_PATH (verify it's installed)
```

### 5. Start the Platform

```bash
# Start all services with env file
docker-compose --env-file .env.prod up -d

# Monitor startup (30-40 seconds)
docker-compose logs -f

# Check status
docker-compose ps
# All should show "Up" with healthy ✓
```

### 6. Verify Deployment

```bash
# Check all services healthy
docker-compose ps
# Look for: Status "Up" and "(healthy)" for all services

# Test RTMP endpoint is ready
echo | nc -z localhost 1935 && echo "RTMP OK" || echo "RTMP FAILED"

# Test HTTP endpoint
curl -I http://localhost:8081/health

# Check logs for errors
docker-compose logs --tail=50 stream-service

# Shell into a service (for debugging)
docker-compose exec stream-service /bin/sh
```

## Port Configuration (Phase 2)

### Public Ports (Exposed Externally)

| Port | Service | Protocol | Purpose | Firewall |
|------|---------|----------|---------|----------|
| **1935** | Ingest | RTMP | Stream ingestion from OBS/FFmpeg | Allow |
| **8081** | Distribution | HTTP | HLS video playback to viewers | Allow |

### Firewall Configuration (UFW)

```bash
# Allow only what's needed
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 1935/tcp           # RTMP ingest
sudo ufw allow 8081/tcp           # HTTP video
sudo ufw allow 22/tcp             # SSH (for management)
sudo ufw enable

# Verify
sudo ufw status numbered
```

### Internal Ports (NOT Exposed)

| Port | Service | Type | Notes |
|------|---------|------|-------|
| 50051-56 | All gRPC | gRPC | Internal service communication only |
| 5432 | Postgres | PostgreSQL | Database (only docker network) |
| 6379 | Redis | Cache | Only docker network |
| 8080 | Services | HTTP | Internal APIs only |
| 8081 | Processing | Metrics | Internal metrics only |

## Optional Addons

### Nginx Reverse Proxy (HTTPS Support)

For production with HTTPS/SSL:

```bash
# Start main platform
docker-compose --env-file .env.prod up -d

# Start Nginx proxy
docker-compose -f docker-compose.yml \
               -f docker-compose.nginx.yml \
               --env-file .env.prod up -d

# Access via https://your-domain.com
```

**Before starting Nginx:**
1. Update `nginx.conf` - change `your-domain.com` to your actual domain
2. Generate SSL certificates (Let's Encrypt recommended):
   ```bash
   sudo certbot certonly --standalone -d your-domain.com
   ```
3. Update cert paths in `docker-compose.nginx.yml`

### Monitoring Stack (Prometheus + Grafana)

For production monitoring:

```bash
# Start monitoring services
docker-compose -f docker-compose.yml \
               -f docker-compose.monitoring.yml \
               --env-file .env.prod up -d

# Access dashboards:
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000
#   - Login: admin / (check .env.prod for GRAFANA_PASSWORD)
```

**Metrics collected:**
- CPU, Memory, Disk usage per container
- Network I/O
- Service response times
- Video quality metrics
- Cache hit rates

## Service Dependencies & Startup Order

The compose file manages startup order automatically:

```
1. Postgres & Redis start immediately
   └─ Both must be healthy (health check passes)

2. DB Service starts (requires Postgres healthy)

3. Auth Service starts (requires Redis + DB healthy)

4. Stream Service starts (requires Auth + DB + Redis healthy)
   └─ This is the orchestrator - others depend on it

5. Ingest & Processing start (require Stream healthy)

6. Distribution starts (requires Redis + Stream healthy)
```

**Total startup time:** ~30-40 seconds

## Common Operations

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f stream-service

# Last N lines
docker-compose logs --tail=100

# Follow with timestamps
docker-compose logs -f --timestamps

# Service-specific (e.g., errors only)
docker-compose logs stream-service 2>&1 | grep -i error
```

### Shell Access

```bash
# Interactive shell in a service
docker-compose exec stream-service /bin/sh

# Run a single command
docker-compose exec db-service grpcurl -plaintext localhost:50051 list

# With specific user
docker-compose exec -u postgres postgres psql -d stream_db
```

### Database Operations

```bash
# Backup Postgres
docker-compose exec postgres pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} \
  > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
docker-compose exec -T postgres psql -U ${POSTGRES_USER} ${POSTGRES_DB} \
  < backup_YYYYMMDD_HHMMSS.sql

# Connect to database
docker-compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
```

### Redis Operations

```bash
# Connect to Redis CLI
docker-compose exec redis redis-cli

# Check memory usage
docker-compose exec redis redis-cli INFO memory

# Flush all data (DANGEROUS!)
docker-compose exec redis redis-cli FLUSHALL
```

### Restart Services

```bash
# Restart a single service
docker-compose restart stream-service

# Restart all services (keeps data)
docker-compose restart

# Hard restart (kill and recreate)
docker-compose down
docker-compose up -d
```

### Update Services

```bash
# Rebuild images from source
docker-compose build

# Rebuild and restart
docker-compose up -d --build

# For specific service only
docker-compose build stream-service
docker-compose up -d stream-service
```

## Resource Limits (Phase 2)

Services have CPU and memory limits configured in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'        # Hard CPU limit
      memory: 1.5G     # Hard memory limit
    reservations:
      cpus: '1.5'      # Guaranteed minimum
      memory: 1G       # Minimum memory
```

**Processing service (most intensive):**
- CPU Limit: 2 cores
- Memory Limit: 1.5GB

**Other services:**
- CPU Limit: 1 core
- Memory Limit: 512MB

**Infrastructure (Postgres/Redis):**
- Postgres: 1.5 cores / 1GB limit
- Redis: 1 core / 512MB limit

**Total: ~5-6 cores / 4-5GB RAM needed**

Adjust limits in `docker-compose.yml` if your VM has different specs.

## Backup & Recovery

### Daily Backup Script

```bash
#!/bin/bash
BACKUP_DIR="/backups/streaming"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T postgres pg_dump -U streaming_user stream_db \
  > $BACKUP_DIR/postgres_$DATE.sql

# Backup Redis
docker-compose exec redis redis-cli BGSAVE
docker volume inspect streaming_redis_data

# Backup recordings/segments (if local)
tar -czf $BACKUP_DIR/recordings_$DATE.tar.gz ./go_ingest/local_recordings

# Keep only last 30 days
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR"
```

### Restore from Backup

```bash
# Restore Postgres
docker-compose exec -T postgres psql -U streaming_user stream_db \
  < backups/postgres_YYYYMMDD_HHMMSS.sql

# Restore recordings
tar -xzf backups/recordings_YYYYMMDD_HHMMSS.tar.gz
```

## Monitoring & Alerts

### Key Metrics to Watch

1. **Disk Space**
   ```bash
   docker-compose exec distribution-service df -h
   # HLS segments grow continuously
   ```

2. **Database Size**
   ```bash
   docker-compose exec postgres psql -U streaming_user -d stream_db \
     -c "SELECT pg_size_pretty(pg_database_size('stream_db'));"
   ```

3. **Memory Usage**
   ```bash
   docker stats
   # Watch for OOMKilled services
   ```

4. **Processing Queue**
   - Check if Processing service can keep up with Ingest rate
   - Monitor FFmpeg errors in logs

### Performance Tuning

If you notice bottlenecks:

```bash
# Increase processing memory if FFmpeg OOM:
# Edit docker-compose.yml, processing-service section:
# memory: 2G (increase from 1.5G)

# Monitor network I/O:
docker stats --no-stream

# Check database connection count:
docker-compose exec postgres psql -U streaming_user -d stream_db \
  -c "SELECT count(*) FROM pg_stat_activity;"
```

## Troubleshooting

### Services fail to start

```bash
# Check compose file syntax
docker-compose config

# Check env file is loaded correctly
docker-compose config | grep DATABASE_DSN

# View service startup errors
docker-compose logs --tail=50 stream-service
```

### Port already in use

```bash
# Find what's using the port
sudo lsof -i :8081

# Kill process or change port in .env
# PORT_MAPPING=127.0.0.1:8082:8080  (internal use only)
```

### Certificate/TLS errors

```bash
# Verify cert files exist and readable
ls -la certs/
ls -la no certs/
# Expected: ca-cert.pem, *-cert.pem, *-key.pem

# Check cert expiry
openssl x509 -in certs/ca-cert.pem -noout -dates

# Regenerate if needed
cd security && ./generate.sh
```

### Database connection failed

```bash
# Check Postgres health
docker-compose exec postgres pg_isready

# Check connection string in .env
docker-compose config | grep DATABASE_DSN

# Verify credentials
docker-compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\l"
```

### Out of memory errors

```bash
# Check which container is using most memory
docker stats --no-stream

# Increase VM memory or reduce container limits
# Check current limits:
docker-compose config | grep memory

# Edit docker-compose.yml to reduce:
# - processing-service: 1.5G → 1G
# - Redis: 512M → 256M
```

## Production Checklist

- [ ] All CHANGE_ME_* values in .env.prod changed
- [ ] Strong passwords generated (32+ chars)
- [ ] Certificates generated/copied to ./certs/
- [ ] Docker installed and running
- [ ] FFmpeg installed on VM
- [ ] Firewall configured (only 1935, 8081 exposed)
- [ ] SSH configured for secure access
- [ ] Backup script set up and tested
- [ ] Monitoring stack deployed (Prometheus+Grafana)
- [ ] Nginx proxy deployed with HTTPS (optional but recommended)
- [ ] All services running and healthy (`docker-compose ps`)
- [ ] Test RTMP ingest with OBS or FFmpeg
- [ ] Test HTTP playback from browser
- [ ] Logs reviewed for errors/warnings
- [ ] Load test with expected stream count
- [ ] Failover/recovery tested
- [ ] Documentation updated with your setup

## Next Steps

1. **Horizontal Scaling** - Add more VMs with distributed storage (S3, MinIO)
2. **Kubernetes** - Migrate to K8s for better orchestration
3. **CDN Integration** - Use CloudFlare/Akamai for edge distribution
4. **Analytics** - Add viewer analytics and stream metrics
5. **Redundancy** - Add database replication and multi-region failover

## Support & Monitoring

For ongoing support:
- Check logs regularly: `docker-compose logs -f`
- Monitor metrics in Grafana: `http://localhost:3000`
- Keep Docker images updated: `docker-compose pull && docker-compose up -d --build`
- Schedule regular backups
- Run health checks: `docker-compose ps`

---

**Last Updated:** April 19, 2026
**Configuration Version:** Phase 2 - Production Optimizations
