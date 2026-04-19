# Security & Certificate Management Guide

## Certificate Generation

### Overview
Certificates are used for mTLS (mutual TLS) authentication between internal services. This ensures only authorized services can communicate with each other.

### Location
- **Scripts:** `security/` folder (in version control)
- **Generated Certificates:** `./certs/` folder (in .gitignore, NOT in version control)

### Certificate Types

1. **CA Certificate** (`ca-cert.pem`)
   - Root certificate authority
   - Signs all service certificates
   - Valid for 3650 days (10 years)
   - Shared across all services

2. **Service Certificates** (e.g., `ingest-cert.pem`, `processing-cert.pem`)
   - Individual certificate for each service
   - Valid for 365 days (1 year)
   - Name-verified against container name

### Generating Certificates

**Option 1: Use current script (basic)**
```bash
cd security
bash generate.sh
# Generates certs in ../certs/
```

**Option 2: Use newer script with SANs (recommended)**
```bash
cd security
bash generate_new.sh
# Better for hostname validation
# Generates certs in ../certs/
```

### Regenerating Certificates

When certificates expire (1 year):

```bash
# 1. Backup old certs
mkdir -p security/certs-backup-$(date +%Y%m%d)
cp certs/* security/certs-backup-$(date +%Y%m%d)/

# 2. Regenerate
cd security
bash generate_new.sh  # Use the newer one
cd ..

# 3. Rebuild containers
docker-compose build
docker-compose up -d
```

### Certificate Locations in Containers

Each service reads certs from:
```yaml
volumes:
  - ./certs:/app/certs:ro         # Most services
  - ./certs:/root/certs:ro         # Processing service
```

All services look for:
- `ca-cert.pem` (required - validates other certs)
- Service-specific cert (e.g., `ingest-cert.pem`)
- Service-specific key (e.g., `ingest-key.pem`)

### Security Best Practices

✅ **DO:**
- Regenerate certificates annually
- Keep ca-key.pem secure (only on generation machine)
- Use stronger key sizes (currently 4096 bits - good)
- Store generated certs separately from code
- Use SANs (Subject Alternative Names) for DNS validation

❌ **DON'T:**
- Commit private keys to version control
- Use weak key sizes (<2048 bits)
- Share certificates across environments
- Reuse certificates across different deployments
- Leave old certificates in certs/ folder

### For Production

**Certificate Rotation Strategy:**
1. Generate new certs 30 days before expiry
2. Update ./certs/ folder
3. Rebuild Docker images: `docker-compose build`
4. Do a rolling restart: `docker-compose up -d`
5. No downtime (services restart gracefully)

**External CA Option:**
If you want to use external CA (optional):
1. Modify generate_new.sh to use your CA
2. Sign certificates with your internal/corporate CA
3. Update ca-cert.pem to your CA cert

### Troubleshooting

**"x509: certificate signed by unknown authority"**
- Cause: ca-cert.pem missing or mismatched
- Fix: Regenerate certificates: `cd security && bash generate_new.sh`

**"x509: certificate has expired"**
- Cause: Certificates older than 365 days
- Fix: Regenerate and rebuild: `docker-compose build && docker-compose up -d`

**"hostname doesn't match"**
- Cause: Certificate SAN doesn't match service hostname
- Fix: Use generate_new.sh which includes SANs

### File Structure

```
Streaming/
├── security/                    # In version control
│   ├── generate.sh             # Basic cert script
│   ├── generate_new.sh         # Better cert script (use this)
│   ├── gen_client.sh           # Legacy
│   └── certs-legacy/           # Old certs (for reference)
│
├── certs/                       # NOT in version control (.gitignore)
│   ├── ca-cert.pem            # CA certificate
│   ├── ca-key.pem             # CA key (SECRET!)
│   ├── db-cert.pem
│   ├── db-key.pem
│   ├── ingest-cert.pem
│   ├── ingest-key.pem
│   ├── processing-cert.pem
│   ├── processing-key.pem
│   ├── distribution-cert.pem
│   └── distribution-key.pem
│
└── .gitignore                   # Prevents accidental commits
```

### Next Steps

1. Commit security/ folder (scripts only)
2. Add .gitignore if not present
3. Never commit ./certs/ folder
4. Document certificate renewal in operations runbook
5. Set calendar reminder for annual certificate rotation

---

**Summary:** Your setup is good! Just ensure:
- ✅ security/ folder is in git (with scripts)
- ❌ certs/ folder is NOT in git (use .gitignore)
- Set reminder for certificate renewal (365 days)
