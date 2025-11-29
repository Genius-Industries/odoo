# GitHub Actions Workflows Documentation

Este documento describe todos los workflows automatizados de GitHub Actions para el proyecto Odoo.

## 📋 Índice

- [Workflows Disponibles](#workflows-disponibles)
- [Configuración Inicial](#configuración-inicial)
- [Deploy to Production](#1-deploy-to-production)
- [CI/CD Testing](#2-cicd-testing)
- [Maintenance & Monitoring](#3-maintenance--monitoring)
- [Automated Backup](#4-automated-backup)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Workflows Disponibles

| Workflow | Archivo | Trigger | Descripción |
|----------|---------|---------|-------------|
| **Deploy to Production** | `deploy-production.yml` | Push a `main`, Manual | Despliega la aplicación a producción |
| **CI/CD Testing** | `ci-testing.yml` | Push, Pull Request | Tests automatizados y validación |
| **Maintenance** | `maintenance.yml` | Schedule (diario), Manual | Mantenimiento y monitoreo del sistema |
| **Backup** | `backup.yml` | Schedule (diario), Manual | Backups automáticos de DB y volúmenes |

---

## ⚙️ Configuración Inicial

### 1. Configurar Secrets

Antes de usar los workflows, debes configurar los secrets necesarios. Ver [SECRETS.md](./SECRETS.md) para instrucciones detalladas.

**Secrets obligatorios**:
- `SSH_HOST`
- `SSH_USER`
- `SSH_PRIVATE_KEY`
- `DOMAIN`
- `ACME_EMAIL`
- `POSTGRES_PASSWORD`
- `TRAEFIK_DASHBOARD_AUTH`

### 2. Preparar el Servidor

En tu servidor de producción:

```bash
# Crear directorio del proyecto
sudo mkdir -p /opt/odoo
sudo chown $USER:$USER /opt/odoo

# Clonar el repositorio
cd /opt/odoo
git clone https://github.com/TU_USUARIO/TU_REPO.git .

# Configurar permisos
chmod 600 traefik/acme.json
```

### 3. Activar GitHub Actions

1. Ve a tu repositorio en GitHub
2. Click en `Settings` → `Actions` → `General`
3. En "Workflow permissions":
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests

---

## 1. Deploy to Production

**Archivo**: `.github/workflows/deploy-production.yml`

### 📌 Propósito

Despliega automáticamente la aplicación Odoo a producción con validaciones de seguridad.

### 🎯 Triggers

- **Automático**: Push a branch `main`
- **Manual**: Workflow dispatch con opción de reiniciar servicios

### 🔄 Flujo del Pipeline

```
1. Validación Pre-Deploy
   ├─ Validar docker-compose files
   ├─ Verificar archivos requeridos
   └─ Validar sintaxis de scripts

2. Security Scanning
   ├─ Trivy security scanner
   └─ Detección de credenciales hardcodeadas

3. Deployment
   ├─ Setup SSH connection
   ├─ Pull cambios del repo
   ├─ Actualizar variables de entorno
   ├─ Pull imágenes Docker
   └─ Desplegar servicios

4. Health Checks
   ├─ Verificar containers activos
   ├─ Test endpoint HTTPS
   └─ Validar servicios

5. Notification
   └─ Reportar status del deployment
```

### 💻 Uso

**Deploy automático**:
```bash
git add .
git commit -m "feat: new feature"
git push origin main
# El workflow se ejecutará automáticamente
```

**Deploy manual**:
1. Ve a `Actions` → `Deploy to Production`
2. Click en `Run workflow`
3. Selecciona branch `main`
4. (Opcional) Marca "Restart services after deployment"
5. Click en `Run workflow`

### 📊 Jobs Incluidos

- **validate**: Pre-deployment validation
- **security-scan**: Security scanning con Trivy
- **deploy**: Deploy a servidor de producción
- **notify**: Notificación de status

### ⏱️ Tiempo Estimado

- Validación: ~2 minutos
- Security Scan: ~1 minuto
- Deploy: ~3-5 minutos
- **Total**: ~6-8 minutos

---

## 2. CI/CD Testing

**Archivo**: `.github/workflows/ci-testing.yml`

### 📌 Propósito

Ejecuta tests automatizados y validaciones en cada cambio del código.

### 🎯 Triggers

- Push a branches: `main`, `develop`, `feature/**`
- Pull requests a: `main`, `develop`

### 🔄 Flujo del Pipeline

```
1. Lint and Validate
   ├─ YAML validation
   ├─ Docker-compose syntax
   ├─ ShellCheck (bash scripts)
   └─ Secret detection

2. Docker Build Test
   ├─ Setup test environment
   ├─ Test Traefik deployment
   ├─ Test Odoo deployment
   ├─ Test DB connectivity
   └─ Test Odoo service

3. Security Scan
   ├─ Trivy vulnerability scan
   └─ Upload results to GitHub Security

4. Documentation Check
   ├─ Verify required docs exist
   └─ Check broken links

5. Script Testing
   ├─ Test setup-env.sh
   ├─ Test validate.sh
   └─ Test Makefile

6. Summary
   └─ Aggregate test results
```

### 💻 Uso

Los tests se ejecutan automáticamente en:

**Pull Requests**:
```bash
git checkout -b feature/nueva-funcionalidad
# ... hacer cambios ...
git push origin feature/nueva-funcionalidad
# Crear PR en GitHub - tests se ejecutan automáticamente
```

**Push a branches**:
```bash
git push origin develop
# Tests se ejecutan automáticamente
```

### 📊 Jobs Incluidos

- **lint-and-validate**: Validación de sintaxis y formato
- **test-docker-build**: Tests de deployment con Docker
- **security-scan**: Escaneo de vulnerabilidades
- **check-documentation**: Validación de documentación
- **test-scripts**: Tests de scripts bash
- **test-results**: Resumen de resultados

### ⏱️ Tiempo Estimado

- Lint: ~1 minuto
- Docker Build Test: ~3-4 minutos
- Security Scan: ~1 minuto
- Docs & Scripts: ~1 minuto
- **Total**: ~6-7 minutos

### ✅ Criterios de Aprobación

Para que un PR sea aprobado, todos estos tests deben pasar:
- ✅ YAML válido
- ✅ Docker compose válido
- ✅ No secrets en código
- ✅ Servicios se inician correctamente
- ✅ DB connectivity OK
- ✅ No vulnerabilidades críticas
- ✅ Documentación completa

---

## 3. Maintenance & Monitoring

**Archivo**: `.github/workflows/maintenance.yml`

### 📌 Propósito

Mantenimiento automatizado y monitoreo del sistema en producción.

### 🎯 Triggers

- **Schedule**: Diario a las 2:00 AM UTC
- **Manual**: Workflow dispatch con opciones

### 🔄 Tareas de Mantenimiento

```
1. Health Check
   ├─ Verificar containers activos
   ├─ Monitorear uso de recursos
   ├─ Verificar disk space
   ├─ Test HTTPS endpoint
   └─ Verificar SSL certificate

2. Update Images
   └─ Pull latest Docker images

3. Cleanup
   ├─ Remover imágenes antiguas
   ├─ Remover volúmenes no usados
   ├─ Remover networks no usadas
   └─ Remover containers detenidos

4. Log Rotation
   ├─ Archivar logs antiguos
   └─ Limpiar logs muy antiguos

5. Backup Check
   ├─ Verificar directorio de backups
   ├─ Listar backups recientes
   └─ Alertar si backup muy antiguo

6. Notification
   └─ Reporte de mantenimiento
```

### 💻 Uso

**Ejecución manual**:
1. Ve a `Actions` → `Maintenance & Monitoring`
2. Click en `Run workflow`
3. Selecciona la tarea:
   - `health-check`: Solo health check
   - `update-images`: Solo actualizar imágenes
   - `cleanup`: Solo limpieza
   - `full-maintenance`: Todas las tareas
4. Click en `Run workflow`

**Ejecución automática**:
Se ejecuta diariamente a las 2:00 AM UTC (11:00 PM hora Colombia)

### 📊 Jobs Incluidos

- **health-check**: Verificación de salud del sistema
- **update-images**: Actualización de imágenes Docker
- **cleanup**: Limpieza de recursos
- **log-rotation**: Rotación de logs
- **backup-check**: Verificación de backups
- **notify**: Reporte de mantenimiento

### ⏱️ Tiempo Estimado

- Health Check: ~2 minutos
- Update Images: ~3 minutos
- Cleanup: ~2 minutos
- Log Rotation: ~1 minuto
- Backup Check: ~1 minuto
- **Total**: ~9 minutos

### 🔔 Alertas

El workflow alertará si:
- ⚠️ Containers no están corriendo
- ⚠️ HTTPS endpoint no accesible
- ⚠️ SSL certificate expira en < 7 días
- ⚠️ Backup más reciente > 2 días
- ⚠️ Disk space bajo

---

## 4. Automated Backup

**Archivo**: `.github/workflows/backup.yml`

### 📌 Propósito

Backups automáticos de la base de datos PostgreSQL y volúmenes Docker.

### 🎯 Triggers

- **Schedule**: Diario a las 3:00 AM UTC
- **Manual**: Workflow dispatch con opciones

### 🔄 Proceso de Backup

```
1. Database Backup
   ├─ Crear backup PostgreSQL
   ├─ Comprimir backup (gzip)
   ├─ Descargar a GitHub runner
   ├─ Subir como artifact
   └─ Limpiar backups antiguos (>7 días)

2. Volumes Backup
   ├─ Backup de odoo-web-data volume
   ├─ Comprimir (tar.gz)
   ├─ Descargar a GitHub runner
   ├─ Subir como artifact
   └─ Limpiar backups antiguos (>7 días)

3. Upload to S3 (opcional)
   ├─ Descargar artifacts
   ├─ Configurar AWS credentials
   ├─ Upload a S3 bucket
   └─ Limpiar S3 backups antiguos (>30 días)

4. Verify Backup
   ├─ Descargar backup de DB
   ├─ Verificar formato PostgreSQL
   └─ Verificar tamaño mínimo

5. Notification
   └─ Reporte de backup
```

### 💻 Uso

**Ejecución manual**:
1. Ve a `Actions` → `Automated Backup`
2. Click en `Run workflow`
3. Selecciona el tipo:
   - `database-only`: Solo backup de DB
   - `volumes-only`: Solo backup de volúmenes
   - `full-backup`: Ambos backups
4. Click en `Run workflow`

**Ejecución automática**:
Se ejecuta diariamente a las 3:00 AM UTC (12:00 AM hora Colombia)

### 📊 Jobs Incluidos

- **backup-database**: Backup de PostgreSQL
- **backup-volumes**: Backup de volúmenes Docker
- **backup-to-s3**: Upload a S3 (opcional)
- **verify-backup**: Verificación de integridad
- **notify**: Reporte de backup

### 💾 Retención de Backups

- **GitHub Artifacts**: 7 días
- **Servidor local**: 7 backups
- **S3 (opcional)**: 30 días

### 📦 Tamaño de Backups

Los backups se almacenan comprimidos:
- Database: ~X MB (variable según datos)
- Volumes: ~Y MB (variable según archivos)

### ⚙️ Configurar S3 (Opcional)

Para habilitar backups en S3:

1. Crear bucket en AWS S3
2. Crear IAM user con permisos S3
3. Configurar secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `BACKUP_BUCKET`
4. Crear variable `ENABLE_S3_BACKUP=true`:
   - `Settings` → `Secrets and variables` → `Actions`
   - Tab `Variables` → `New repository variable`
   - Name: `ENABLE_S3_BACKUP`
   - Value: `true`

### 🔄 Restaurar un Backup

**Desde GitHub Artifacts**:
```bash
# Descargar artifact desde GitHub Actions UI
# Extraer archivo

# Restaurar DB
gunzip odoo_db_*.sql.gz
make restore-db FILE=odoo_db_*.sql

# Restaurar volumes
tar xzf odoo-data_*.tar.gz
docker run --rm -v odoo-web-data:/data -v $(pwd):/backup \
  ubuntu tar xzf /backup/odoo-data_*.tar.gz -C /
```

**Desde S3**:
```bash
# Descargar desde S3
aws s3 cp s3://tu-bucket/odoo-backups/2025/11/30/odoo_db_*.sql.gz .

# Restaurar como arriba
```

### ⏱️ Tiempo Estimado

- DB Backup: ~2 minutos
- Volumes Backup: ~3 minutos
- S3 Upload: ~2 minutos (si habilitado)
- Verification: ~1 minuto
- **Total**: ~6-8 minutos

---

## 🐛 Troubleshooting

### Workflow no se ejecuta

**Problema**: El workflow no aparece en Actions

**Soluciones**:
1. Verifica que el archivo está en `.github/workflows/`
2. Verifica sintaxis YAML: `python3 -c "import yaml; yaml.safe_load(open('file.yml'))"`
3. Verifica permisos de Actions en Settings
4. Push a una branch que matchee el trigger

### Deploy falla con "Permission denied"

**Problema**: Error de SSH durante deploy

**Soluciones**:
1. Verifica que `SSH_PRIVATE_KEY` está completo (incluye BEGIN/END)
2. Verifica que la llave pública está en `~/.ssh/authorized_keys` del servidor
3. Verifica permisos: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`
4. Test manual: `ssh -i key user@host`

### Tests de Docker fallan

**Problema**: Docker build test falla

**Soluciones**:
1. Verifica sintaxis docker-compose: `docker compose config`
2. Verifica que las imágenes existen
3. Revisa logs del workflow para detalles
4. Test local: `docker compose up -d`

### Health check falla

**Problema**: Health check reporta servicios down

**Soluciones**:
1. SSH al servidor y verifica: `docker ps`
2. Verifica logs: `docker compose logs`
3. Verifica recursos del servidor: `df -h`, `free -h`
4. Reinicia servicios: `make restart`

### Backup falla

**Problema**: Backup workflow falla

**Soluciones**:
1. Verifica espacio en disco del servidor
2. Verifica que el container `odoo_db` está corriendo
3. Verifica permisos del directorio `backups/`
4. Si S3: verifica credentials de AWS

### SSL certificate check falla

**Problema**: Alerta de certificado expirado

**Soluciones**:
1. Verifica que Traefik está corriendo
2. Verifica configuración ACME en `traefik.yml`
3. Verifica `ACME_EMAIL` en secrets
4. Fuerza renovación: Reinicia Traefik

---

## 📊 Monitoreo y Métricas

### Ver Status de Workflows

```bash
# Usando GitHub CLI
gh run list --workflow=deploy-production.yml
gh run list --workflow=ci-testing.yml
gh run list --workflow=maintenance.yml
gh run list --workflow=backup.yml

# Ver logs de un run específico
gh run view RUN_ID --log
```

### Badges de Status

Agrega badges a tu README.md:

```markdown
![Deploy](https://github.com/TU_USUARIO/TU_REPO/actions/workflows/deploy-production.yml/badge.svg)
![CI](https://github.com/TU_USUARIO/TU_REPO/actions/workflows/ci-testing.yml/badge.svg)
![Maintenance](https://github.com/TU_USUARIO/TU_REPO/actions/workflows/maintenance.yml/badge.svg)
![Backup](https://github.com/TU_USUARIO/TU_REPO/actions/workflows/backup.yml/badge.svg)
```

---

## 🔗 Referencias

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [SECRETS.md](./SECRETS.md) - Configuración de secrets
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Guía de deployment manual

---

**Última actualización**: 2025-11-30
**Versión**: 1.0.0
