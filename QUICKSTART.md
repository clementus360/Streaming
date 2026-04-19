# Quick Start - Ready to Deploy

## ✅ Setup Complete

All prerequisites are now in place:

```
✅ Certificates generated: ./certs/
   - ca-cert.pem (Certificate Authority)
   - ingest-cert.pem, ingest-key.pem
   - processing-cert.pem, processing-key.pem
   - distribution-cert.pem, distribution-key.pem
   - db-cert.pem, db-key.pem

✅ Environment configuration
   - .env.dev: Development defaults (ready to use)
   - .env.production: Production template (customize for production)

✅ Docker Compose: All services configured
   - docker-compose.yml: Main 6 services
   - docker-compose.nginx.yml: Optional Nginx reverse proxy
   - docker-compose.monitoring.yml: Optional monitoring stack
```

## 🚀 Start Services Now

### Development (simplest, fully functional)
```bash
cd /Users/clement/Documents/CODE/Streaming

# Start all 6 services (with development defaults)
docker-compose --env-file .env.dev up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Production (with your own values)
```bash
# Copy and customize environment
cp .env.production .env.prod
nano .env.prod  # Edit with your production values

# Start with production config
docker-compose --env-file .env.prod up -d
```

## 🔍 Verify Services are Running

```bash
# Check all containers
docker-compose ps

# Should see all 8 containers:
# - postgres (✓ healthy)
# - redis (✓ healthy)
# - db-service (✓ running)
# - auth-service (✓ running)
# - stream-service (✓ running)
# - ingest-service (✓ running)
# - processing-service (✓ running)
# - distribution-service (✓ running)

# Test RTMP endpoint (port 1935)
echo | nc -z localhost 1935 && echo "RTMP: OK" || echo "RTMP: FAILED"

# Test HTTP endpoint (port 8081)
curl -I http://localhost:8081/health

# View real-time logs
docker-compose logs -f
```

## 📝 Default Credentials (Development)

**Database (Postgres):**
- User: `user`
- Password: `password`
- Database: `stream_db`
- Connection: `postgres://user:password@postgres:5432/stream_db`

**Authentication (JWT):**
- Secret: `dev_jwt_secret_32_character_minimum_key`

**Email (Notifications):**
- Sender: `noreply@localhost`

## 🔐 For Production

1. **Never use .env.dev in production**
2. **Use .env.prod with strong values:**
   ```bash
   # Generate strong passwords
   openssl rand -base64 32
   
   # Copy and edit
   cp .env.production .env.prod
   nano .env.prod
   
   # Update:
   # - POSTGRES_PASSWORD (strong, 32+ chars)
   # - JWT_SECRET (strong, unique)
   # - BASE_URL (your domain)
   # - RESEND_KEY (your email API key)
   # - Grafana password
   ```

## 📊 What's Running

| Service | Port | Role |
|---------|------|------|
| **Ingest** | 1935 | RTMP stream ingestion |
| **Distribution** | 8081 | HTTP video playback (HLS) |
| **Stream Service** | Internal (50051) | Orchestration |
| **Auth Service** | Internal (50051) | Authentication |
| **DB Service** | Internal (50051) | Database proxy |
| **Processing** | Internal (50051) | FFmpeg transcoding |
| **Postgres** | Internal (5432) | Primary database |
| **Redis** | Internal (6379) | Cache/session storage |

## 🛠️ Common Commands

```bash
# View service-specific logs
docker-compose logs -f stream-service
docker-compose logs -f processing-service

# Shell into a service
docker-compose exec stream-service /bin/sh

# Backup database
docker-compose exec postgres pg_dump -U user stream_db > backup.sql

# Restart a service
docker-compose restart stream-service

# Stop everything (keeps data)
docker-compose down

# Remove everything (reset, deletes data)
docker-compose down -v
```

## 📚 Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Full production guide
- [docker-compose.yml](docker-compose.yml) - Service configuration
- [nginx.conf](nginx.conf) - Optional reverse proxy (HTTPS)
- [prometheus.yml](prometheus.yml) - Optional monitoring

---

**Ready to go!** Run: `docker-compose --env-file .env.dev up -d`
