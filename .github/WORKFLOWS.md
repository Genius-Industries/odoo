# Workflows Documentation

Documentación técnica detallada de todos los workflows de GitHub Actions.

---

## Architecture Overview

```
GitHub Repository
       │
       ├── Push/PR → validate-config.yml
       │
       ├── Release → deploy-production.yml
       │
       ├── Cron Daily → backup-database.yml
       │
       └── Manual → rollback.yml
```

---

## 1. Deploy to Production

**File**: `workflows/deploy-production.yml`

### Triggers

```yaml
on:
  release:
    types: [published]  # Cuando se publica un release
  workflow_dispatch:     # Manual desde GitHub UI
```

### Environment Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `DOMAIN` | GitHub Secret | Dominio principal |
| `ODOO_VERSION` | GitHub Secret | Versión de Odoo |
| `ACME_EMAIL` | GitHub Secret | Email para Let's Encrypt |
| `TRAEFIK_DASHBOARD_AUTH` | GitHub Secret | Auth del dashboard |
| `POSTGRES_PASSWORD` | GitHub Secret | Password de PostgreSQL |
| `TZ` | GitHub Secret | Zona horaria |

### Steps Breakdown

#### Step 1: Checkout
```yaml
- uses: actions/checkout@v4
```
Descarga el código del repositorio.

#### Step 2: Setup Environment
```yaml
- run: |
    echo "DOMAIN=${{ secrets.DOMAIN }}" > .env
    # ... más variables
```
Crea archivo `.env` con secrets de GitHub.

#### Step 3: Setup Secrets
```yaml
- run: |
    echo "${{ secrets.POSTGRES_PASSWORD }}" > odoo_pg_pass
    chmod 600 odoo_pg_pass
```
Crea archivo de secret para PostgreSQL con permisos correctos.

#### Step 4: Validate Config
```yaml
- run: docker compose config > /dev/null
```
Valida sintaxis del docker-compose.yml antes de continuar.

#### Step 5: Pull Images
```yaml
- run: docker compose pull
```
Descarga las últimas versiones de las imágenes.

#### Step 6: Build
```yaml
- run: docker compose build
```
Construye imágenes custom si existen Dockerfiles.

#### Step 7: Stop Old
```yaml
- run: docker compose down --timeout 30
```
Detiene containers anteriores de forma graceful (30 seg timeout).

#### Step 8: Start Services
```yaml
- run: docker compose up -d
```
Inicia todos los servicios en modo daemon.

#### Step 9: Health Checks
```yaml
- run: |
    docker compose exec -T db pg_isready -U odoo -d postgres
    docker compose exec -T odoo curl -f http://localhost:8069/web/health
```
Verifica que los servicios estén saludables antes de considerar deployment exitoso.

#### Step 10: Cleanup
```yaml
- run: docker image prune -af --filter "until=24h"
```
Limpia imágenes antiguas para liberar espacio.

### Failure Handling

Si cualquier step falla, el workflow se detiene y marca el deployment como fallido.

**Rollback manual**:
```bash
# Ejecutar workflow de rollback
gh workflow run rollback.yml -f backup_date=20241130_020000
```

---

## 2. Validate Configuration

**File**: `workflows/validate-config.yml`

### Triggers

```yaml
on:
  push:
    branches: [main, master, develop]
  pull_request:
    branches: [main, master, develop]
```

### Purpose

Validar que los cambios no rompan la configuración antes de hacer merge.

### Validations

1. **Sintaxis Docker Compose**:
   ```bash
   docker compose config > /dev/null
   ```

2. **Archivos Requeridos**:
   - docker-compose.yml
   - .env
   - odoo_pg_pass
   - README.md

3. **Variables de Entorno**:
   - DOMAIN
   - ODOO_VERSION
   - ACME_EMAIL
   - TRAEFIK_DASHBOARD_AUTH

4. **Configuración de Red**:
   - Verifica que todos los servicios usen `traefik-public`

### Success Criteria

Todos los checks deben pasar para que el PR pueda mergearse.

---

## 3. Backup Database

**File**: `workflows/backup-database.yml`

### Triggers

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Diario a las 2 AM UTC
  workflow_dispatch:      # Manual
```

### Process

```
1. Crear directorio /backups/odoo
         │
         ▼
2. pg_dumpall > backup_YYYYMMDD_HHMMSS.sql
         │
         ▼
3. gzip backup.sql
         │
         ▼
4. Verificar integridad
         │
         ▼
5. Limpiar backups antiguos (mantener 7)
```

### Backup Location

```
/backups/odoo/odoo_backup_YYYYMMDD_HHMMSS.sql.gz
```

### Retention Policy

- **Mantener**: Últimos 7 backups
- **Eliminar**: Backups más antiguos de 7 días

### Restore Process

Ver workflow `rollback.yml`.

---

## 4. Rollback Deployment

**File**: `workflows/rollback.yml`

### Triggers

```yaml
on:
  workflow_dispatch:
    inputs:
      backup_date:
        description: 'Backup date (YYYYMMDD_HHMMSS)'
        required: true
```

### Process

```
1. Detener servicios actuales
         │
         ▼
2. Verificar que backup existe
         │
         ▼
3. Iniciar solo PostgreSQL
         │
         ▼
4. Restaurar backup:
   gunzip -c backup.sql.gz | psql
         │
         ▼
5. Reiniciar todos los servicios
         │
         ▼
6. Health checks
```

### Usage

**Desde GitHub UI**:
```
Actions → Rollback Deployment → Run workflow
Input: 20241130_020000
```

**Desde CLI**:
```bash
gh workflow run rollback.yml -f backup_date=20241130_020000
```

### Verification

```bash
# En VPS después del rollback
docker compose ps
docker compose logs odoo | tail -50
```

---

## Runner Requirements

### Labels

Los workflows requieren runner con labels:
```yaml
runs-on:
  - self-hosted
  - production
```

### Setup

Ver `RUNNER_SETUP.md` para configuración completa.

**Verificar labels**:
```
GitHub Settings → Actions → Runners → [tu runner]
Labels: self-hosted, Linux, X64, production
```

---

## Secrets Required

Ver `SECRETS.md` para lista completa y cómo configurarlos.

**Mínimos requeridos**:
- `DOMAIN`
- `ODOO_VERSION`
- `ACME_EMAIL`
- `TRAEFIK_DASHBOARD_AUTH`
- `POSTGRES_PASSWORD`
- `TZ`

---

## Best Practices

### 1. Testing de Workflows

Antes de usar en producción:

```yaml
# Agregar a workflow
on:
  workflow_dispatch:  # Permite test manual
```

```bash
# Ejecutar manualmente
gh workflow run deploy-production.yml
```

### 2. Dry Run

Para probar sin hacer deployment:

```yaml
- name: Dry run
  run: |
    docker compose config
    echo "Would deploy to: ${{ secrets.DOMAIN }}"
  # Comentar steps de deployment real
```

### 3. Notificaciones

Agregar notificaciones al final:

```yaml
- name: Notify on success
  if: success()
  run: |
    curl -X POST $WEBHOOK_URL \
      -d "Deployment successful to ${{ secrets.DOMAIN }}"

- name: Notify on failure
  if: failure()
  run: |
    curl -X POST $WEBHOOK_URL \
      -d "Deployment failed!"
```

### 4. Rollback Automático

Para rollback automático en caso de fallo:

```yaml
- name: Deploy
  id: deploy
  run: docker compose up -d

- name: Health check
  run: |
    if ! docker compose exec odoo curl -f localhost:8069; then
      docker compose down
      # Restaurar versión anterior
      exit 1
    fi
```

---

## Advanced Configuration

### Environment-Specific Deployments

Para tener staging y production:

```yaml
jobs:
  deploy-staging:
    environment: staging
    if: github.ref == 'refs/heads/develop'
    # ... steps

  deploy-production:
    environment: production
    if: github.ref == 'refs/heads/main'
    # ... steps
```

### Matrix Builds

Para deployar a múltiples servers:

```yaml
strategy:
  matrix:
    server: [production, backup]
runs-on:
  - self-hosted
  - ${{ matrix.server }}
```

### Conditional Steps

```yaml
- name: Run only on production
  if: github.event_name == 'release'
  run: # production-only commands

- name: Run only on PR
  if: github.event_name == 'pull_request'
  run: # validation-only commands
```

---

## Monitoring Workflows

### GitHub UI

```
Actions → [Workflow] → [Run]
```

Ver:
- Status (success/failure)
- Duration
- Logs de cada step
- Artifacts (si hay)

### GitHub CLI

```bash
# Listar workflows
gh workflow list

# Ver runs recientes
gh run list --limit 10

# Ver detalles de un run
gh run view RUN_ID

# Ver logs
gh run view RUN_ID --log

# Re-ejecutar workflow fallido
gh run rerun RUN_ID
```

### Logs del Runner

```bash
# En VPS
sudo journalctl -u actions.runner.* -f

# Logs específicos del runner
cd /home/github-runner/actions-runner
tail -f _diag/*.log
```

---

## Troubleshooting

### Workflow no se ejecuta

**Causas posibles**:
1. Runner offline
2. Trigger incorrecto
3. Branch protection rules

**Solución**:
```bash
# Verificar runner
gh api /repos/OWNER/REPO/actions/runners

# Ver workflows
gh workflow list

# Ejecutar manualmente
gh workflow run WORKFLOW_NAME
```

### Workflow falla en step específico

**Diagnóstico**:
1. Ver logs del step en GitHub UI
2. Reproducir comando localmente en VPS
3. Verificar secrets configurados

**Solución**:
```bash
# SSH al VPS
ssh usuario@vps

# Ejecutar comando fallido manualmente
cd /home/geniusdev/WorkSpace/odoo
# ... comando que falló
```

### Timeout en health checks

**Causa**: Odoo tarda en iniciar

**Solución**: Aumentar timeout o intentos
```yaml
max_attempts=60  # Aumentar de 30
sleep 10         # Aumentar delay inicial
```

---

## Performance Optimization

### Cache de Docker Layers

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Cache Docker layers
  uses: actions/cache@v3
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
```

### Parallel Jobs

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    # ... validation

  deploy:
    needs: validate
    runs-on: self-hosted
    # ... deployment
```

---

## Security Considerations

### ✅ Implemented

- Secrets no expuestos en logs
- Runner en servidor privado
- Validación antes de deployment
- Health checks antes de finalizar

### 🔒 Additional Recommendations

1. **Audit logs**:
   ```
   Settings → Actions → General → Workflow permissions
   ```

2. **Require approval**:
   ```yaml
   environment:
     name: production
     # Requiere aprobación manual
   ```

3. **Limit runner access**:
   ```
   Settings → Actions → Runner groups
   ```

---

**Última actualización**: 2024-11-30
