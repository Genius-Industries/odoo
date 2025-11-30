# CI/CD Flow Diagram

Diagramas visuales del flujo completo de CI/CD.

---

## Flujo Principal de Development → Production

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVELOPMENT PHASE                             │
└─────────────────────────────────────────────────────────────────────┘

Developer                GitHub                    CI/CD
    │                        │                         │
    │  git push              │                         │
    ├───────────────────────>│                         │
    │                        │                         │
    │                        │  Trigger: validate-config.yml
    │                        ├────────────────────────>│
    │                        │                         │
    │                        │                         │ Validate
    │                        │                         │ ├─ Check syntax
    │                        │                         │ ├─ Verify files
    │                        │                         │ └─ Check .env
    │                        │                         │
    │                        │      ✓ Validation OK    │
    │                        │<────────────────────────┤
    │                        │                         │
    │  Create PR             │                         │
    ├───────────────────────>│                         │
    │                        │                         │
    │                        │  Trigger: validate-config.yml
    │                        ├────────────────────────>│
    │                        │                         │
    │                        │      ✓ PR Checks Pass   │
    │                        │<────────────────────────┤
    │                        │                         │
    │  Merge PR              │                         │
    ├───────────────────────>│                         │
    │                        │                         │

┌─────────────────────────────────────────────────────────────────────┐
│                         RELEASE PHASE                                │
└─────────────────────────────────────────────────────────────────────┘

Developer                GitHub                    Self-Hosted Runner
    │                        │                             │
    │  Create Release        │                             │
    │  v1.0.0               │                             │
    ├───────────────────────>│                             │
    │                        │                             │
    │                        │  Trigger: deploy-production.yml
    │                        ├────────────────────────────>│
    │                        │                             │
    │                        │                             │ 1. Checkout code
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 2. Setup .env
    │                        │                             │ (from secrets)
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 3. Validate config
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 4. Pull images
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 5. Build
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 6. Stop old
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 7. Start new
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 8. Health checks
    │                        │                             │ ├─ PostgreSQL
    │                        │                             │ └─ Odoo
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │                             │ 9. Cleanup
    │                        │                             ├──────────────>
    │                        │                             │
    │                        │       ✓ Deployment OK       │
    │                        │<────────────────────────────┤
    │                        │                             │
    │ ✓ Notification         │                             │
    │<───────────────────────┤                             │
    │                        │                             │

┌─────────────────────────────────────────────────────────────────────┐
│                      PRODUCTION RUNNING                              │
└─────────────────────────────────────────────────────────────────────┘

                    ┌────────────────────┐
                    │   GitHub Cron      │
                    │   Daily 2 AM UTC   │
                    └─────────┬──────────┘
                              │
                              │ Trigger: backup-database.yml
                              ▼
                    ┌────────────────────┐
                    │  Self-Hosted       │
                    │  Runner            │
                    └─────────┬──────────┘
                              │
                              │ 1. pg_dumpall
                              │ 2. gzip
                              │ 3. Save to /backups/
                              │ 4. Clean old backups
                              ▼
                    ┌────────────────────┐
                    │  Backup Stored     │
                    │  /backups/odoo/    │
                    └────────────────────┘
```

---

## Flujo de Rollback

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ROLLBACK FLOW                                │
└─────────────────────────────────────────────────────────────────────┘

Incident                GitHub                    Self-Hosted Runner
    │                       │                             │
    │  Manual Trigger       │                             │
    │  rollback.yml        │                             │
    │  backup_date=...     │                             │
    ├──────────────────────>│                             │
    │                       │                             │
    │                       │  Trigger: rollback.yml      │
    │                       ├────────────────────────────>│
    │                       │                             │
    │                       │                             │ 1. Stop services
    │                       │                             ├──────────────>
    │                       │                             │
    │                       │                             │ 2. Verify backup
    │                       │                             │    exists
    │                       │                             ├──────────────>
    │                       │                             │
    │                       │                             │ 3. Start DB only
    │                       │                             ├──────────────>
    │                       │                             │
    │                       │                             │ 4. Restore backup
    │                       │                             │    gunzip | psql
    │                       │                             ├──────────────>
    │                       │                             │
    │                       │                             │ 5. Restart all
    │                       │                             ├──────────────>
    │                       │                             │
    │                       │                             │ 6. Health checks
    │                       │                             ├──────────────>
    │                       │                             │
    │                       │       ✓ Rollback OK         │
    │                       │<────────────────────────────┤
    │                       │                             │
    │ ✓ Notification        │                             │
    │<──────────────────────┤                             │
    │                       │                             │
```

---

## Componentes del Sistema

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GITHUB REPOSITORY                            │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    .github/workflows/                          │ │
│  │                                                                │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                  │ │
│  │  │ deploy-          │  │ validate-        │                  │ │
│  │  │ production.yml   │  │ config.yml       │                  │ │
│  │  └──────────────────┘  └──────────────────┘                  │ │
│  │                                                                │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                  │ │
│  │  │ backup-          │  │ rollback.yml     │                  │ │
│  │  │ database.yml     │  │                  │                  │ │
│  │  └──────────────────┘  └──────────────────┘                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                     GitHub Secrets                             │ │
│  │                                                                │ │
│  │  • DOMAIN                 • ACME_EMAIL                        │ │
│  │  • ODOO_VERSION           • TRAEFIK_DASHBOARD_AUTH            │ │
│  │  • POSTGRES_PASSWORD      • TZ                                │ │
│  └───────────────────────────────────────────────────────────────┘ │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           │ Webhook / Trigger
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                            VPS SERVER                                │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │              GitHub Actions Runner Service                     │ │
│  │              User: github-runner                               │ │
│  │              Labels: self-hosted, production                   │ │
│  └────────────────────────┬──────────────────────────────────────┘ │
│                           │                                          │
│                           │ Controls                                 │
│                           ▼                                          │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                   Docker Compose Stack                         │ │
│  │                                                                │ │
│  │  ┌─────────────┐   ┌─────────────┐   ┌──────────────────┐   │ │
│  │  │   Traefik   │   │    Odoo     │   │   PostgreSQL     │   │ │
│  │  │   v3.6.2    │   │    19.0     │   │       15         │   │ │
│  │  │             │   │             │   │                  │   │ │
│  │  │ • SSL/TLS   │   │ • ERP       │   │ • Database       │   │ │
│  │  │ • Routing   │   │ • Web UI    │   │ • Persistence    │   │ │
│  │  └─────────────┘   └─────────────┘   └──────────────────┘   │ │
│  │                                                                │ │
│  │  Network: traefik-public                                      │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                      Backups Storage                           │ │
│  │                   /backups/odoo/                               │ │
│  │                                                                │ │
│  │  • odoo_backup_20241130_020000.sql.gz                         │ │
│  │  • odoo_backup_20241129_020000.sql.gz                         │ │
│  │  • ... (últimos 7 backups)                                    │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Estados de Workflow

```
┌────────────────────────────────────────────────────────────┐
│                   Workflow Lifecycle                        │
└────────────────────────────────────────────────────────────┘

    Triggered
        │
        ▼
    Queued ──────────> Waiting for runner
        │                     │
        │                     ▼
        │              Runner not available
        │                     │
        │                     ▼
        │                  Timeout
        │
        ▼
    Running
        │
        ├──────> Step 1 ✓
        ├──────> Step 2 ✓
        ├──────> Step 3 ✗ (Error)
        │             │
        │             ▼
        │         Failed ──────> Send notification
        │                             │
        │                             ▼
        │                        Manual rollback
        │
        ├──────> Step 4 ✓
        ├──────> Step 5 ✓
        │
        ▼
    Completed ──────> Success
        │
        ▼
    Send notification
```

---

## Health Check Flow

```
┌────────────────────────────────────────────────────────────┐
│              Health Check After Deployment                  │
└────────────────────────────────────────────────────────────┘

Start
  │
  ├─> Wait 10 seconds (initial delay)
  │
  ├─> Check PostgreSQL
  │   │
  │   ├─> pg_isready -U odoo -d postgres
  │   │
  │   ├─> Success? ──Yes──> Continue
  │   │
  │   └─> No ────────────> FAIL (rollback)
  │
  ├─> Check Odoo (loop max 30 times)
  │   │
  │   ├─> curl http://localhost:8069/web/health
  │   │
  │   ├─> Success? ──Yes──> Continue
  │   │
  │   ├─> No ────────────> Wait 5 seconds
  │   │                     │
  │   │                     └─> Retry
  │   │
  │   └─> 30 attempts exhausted ──> FAIL (rollback)
  │
  └─> All checks passed ──> SUCCESS
      │
      └─> Deployment confirmed
```

---

## Backup Retention Policy

```
┌────────────────────────────────────────────────────────────┐
│                   Backup Retention                          │
└────────────────────────────────────────────────────────────┘

Daily Backup (2 AM UTC)
        │
        ├─> Create: odoo_backup_YYYYMMDD_HHMMSS.sql
        ├─> Compress: gzip
        ├─> Verify: Check file size > 0
        │
        ├─> Count existing backups
        │   │
        │   ├─> 7 or less ────> Keep all
        │   │
        │   └─> More than 7 ──> Delete oldest
        │                        │
        │                        └─> Keep newest 7
        │
        └─> Result:
            /backups/odoo/
              ├── odoo_backup_20241130_020000.sql.gz  (Today)
              ├── odoo_backup_20241129_020000.sql.gz  (Day -1)
              ├── odoo_backup_20241128_020000.sql.gz  (Day -2)
              ├── odoo_backup_20241127_020000.sql.gz  (Day -3)
              ├── odoo_backup_20241126_020000.sql.gz  (Day -4)
              ├── odoo_backup_20241125_020000.sql.gz  (Day -5)
              └── odoo_backup_20241124_020000.sql.gz  (Day -6)

            Older backups deleted automatically
```

---

## Security Flow

```
┌────────────────────────────────────────────────────────────┐
│                    Security Measures                        │
└────────────────────────────────────────────────────────────┘

GitHub Repository
        │
        ├─> Secrets stored encrypted
        │   └─> Never exposed in logs
        │
        ├─> Workflows read from protected branch
        │   └─> Require review for changes
        │
        └─> Webhook to VPS
            └─> HTTPS only

VPS Self-Hosted Runner
        │
        ├─> Dedicated user: github-runner
        │   └─> No root access
        │
        ├─> Docker socket access
        │   └─> Limited to github-runner group
        │
        ├─> Secrets written to files
        │   ├─> .env (600 permissions)
        │   └─> odoo_pg_pass (600 permissions)
        │
        ├─> Network isolation
        │   └─> traefik-public (bridge)
        │
        └─> Firewall rules
            ├─> 80/tcp (HTTP)
            ├─> 443/tcp (HTTPS)
            └─> 22/tcp (SSH - key only)

Production Deployment
        │
        ├─> Traefik
        │   ├─> Auto SSL/TLS (Let's Encrypt)
        │   └─> Dashboard protected (basic auth)
        │
        ├─> Odoo
        │   └─> Only accessible via Traefik
        │
        └─> PostgreSQL
            ├─> No external exposure
            └─> Password in Docker secret
```

---

## Timeline Example: Release to Production

```
Time    Event                              Duration
─────────────────────────────────────────────────────────────
00:00   Developer creates release          Manual
00:01   GitHub triggers workflow           Instant
00:02   Runner picks up job                < 5 sec
00:03   Checkout code                      ~ 10 sec
00:04   Setup .env from secrets            ~ 2 sec
00:05   Validate docker-compose            ~ 3 sec
00:06   Pull latest images                 ~ 30 sec
00:37   Build custom images                ~ 20 sec
00:57   Stop old containers                ~ 10 sec
01:07   Start new containers               ~ 5 sec
01:12   Wait for PostgreSQL                ~ 10 sec
01:22   Wait for Odoo                      ~ 30 sec
01:52   Health checks pass                 ~ 5 sec
01:57   Cleanup old images                 ~ 10 sec
02:07   Deployment complete                ✓

Total: ~2 minutes 7 seconds
```

---

**Última actualización**: 2024-11-30
