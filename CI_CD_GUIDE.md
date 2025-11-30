# CI/CD Complete Guide

Guía completa para configurar CI/CD con GitHub Actions para Odoo.

---

## 📋 Índice

1. [Introducción](#introducción)
2. [Arquitectura CI/CD](#arquitectura-cicd)
3. [Setup Rápido](#setup-rápido)
4. [Workflows Disponibles](#workflows-disponibles)
5. [Uso Diario](#uso-diario)
6. [Troubleshooting](#troubleshooting)

---

## Introducción

Este proyecto incluye un sistema completo de CI/CD con:

- ✅ **Deployment automático** cuando creas un release
- ✅ **Validación automática** en cada push/PR
- ✅ **Backups diarios** de base de datos
- ✅ **Rollback** con un click

---

## Arquitectura CI/CD

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Repository                       │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    .github/workflows                  │  │
│  │                                                       │  │
│  │  • deploy-production.yml   (Release → Deploy)        │  │
│  │  • validate-config.yml     (Push/PR → Validate)      │  │
│  │  • backup-database.yml     (Daily → Backup)          │  │
│  │  • rollback.yml            (Manual → Restore)        │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Webhook/Trigger
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    VPS (Self-Hosted Runner)                  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         GitHub Actions Runner Service                │  │
│  │         User: github-runner                          │  │
│  │         Labels: self-hosted, production              │  │
│  └──────────────┬───────────────────────────────────────┘  │
│                 │                                            │
│                 │ Execute workflow                           │
│                 ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Docker Compose Stack                       │  │
│  │                                                       │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │  │
│  │  │ Traefik  │  │   Odoo   │  │   PostgreSQL     │  │  │
│  │  │  Proxy   │  │   19.0   │  │      15          │  │  │
│  │  └──────────┘  └──────────┘  └──────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Setup Rápido

### Paso 1: Configurar Runner (10 min)

```bash
# En tu VPS
ssh usuario@tu-vps

# Crear usuario para runner
sudo useradd -m -s /bin/bash github-runner
sudo usermod -aG docker github-runner

# Cambiar a usuario runner
sudo su - github-runner
mkdir actions-runner && cd actions-runner

# Seguir instrucciones de GitHub:
# Settings → Actions → Runners → New self-hosted runner
# Copiar y ejecutar comandos de descarga y configuración

# Instalar como servicio
sudo ./svc.sh install github-runner
sudo ./svc.sh start
```

**Ver guía completa**: [`.github/RUNNER_SETUP.md`](.github/RUNNER_SETUP.md)

### Paso 2: Configurar Secrets (5 min)

**Opción A: Script automático**
```bash
# En tu máquina local (con gh CLI instalado)
cd /home/geniusdev/WorkSpace/odoo
./setup-github-secrets.sh
```

**Opción B: Manual en GitHub**
```
GitHub → Settings → Secrets and variables → Actions
Agregar:
- DOMAIN
- ODOO_VERSION
- ACME_EMAIL
- TRAEFIK_DASHBOARD_AUTH
- POSTGRES_PASSWORD
- TZ
```

**Ver guía completa**: [`.github/SECRETS.md`](.github/SECRETS.md)

### Paso 3: Push de Workflows (1 min)

```bash
git add .github/
git commit -m "Add GitHub Actions CI/CD"
git push
```

### Paso 4: Test (2 min)

```bash
# Crear release para activar deployment
gh release create v1.0.0 --title "Production Release v1.0.0"

# Ver progreso
gh run list
gh run watch
```

**Total**: ~18 minutos

---

## Workflows Disponibles

### 1. Deploy to Production

**Trigger**: Release published o manual

**¿Qué hace?**
1. Descarga código
2. Configura .env con secrets
3. Valida docker-compose.yml
4. Hace pull de imágenes
5. Detiene containers antiguos
6. Inicia nuevos containers
7. Verifica health
8. Limpia imágenes antiguas

**Uso**:
```bash
# Crear release (automático)
gh release create v1.0.1 --title "Release v1.0.1"

# Manual
# GitHub → Actions → Deploy to Production → Run workflow
```

**Duración**: ~2-5 minutos

---

### 2. Validate Configuration

**Trigger**: Push o PR a main/master/develop

**¿Qué hace?**
1. Valida sintaxis docker-compose.yml
2. Verifica archivos requeridos
3. Valida variables de entorno
4. Verifica configuración de red

**Uso**: Automático en cada push/PR

**Duración**: ~30 segundos

---

### 3. Backup Database

**Trigger**: Diario a las 2 AM UTC o manual

**¿Qué hace?**
1. Crea backup completo de PostgreSQL
2. Comprime con gzip
3. Guarda en `/backups/odoo/`
4. Limpia backups antiguos (mantiene 7)

**Uso**:
```bash
# Manual
# GitHub → Actions → Backup Database → Run workflow
```

**Duración**: ~1-3 minutos (según tamaño BD)

---

### 4. Rollback Deployment

**Trigger**: Manual con fecha de backup

**¿Qué hace?**
1. Detiene servicios
2. Restaura backup especificado
3. Reinicia servicios
4. Verifica health

**Uso**:
```bash
# GitHub → Actions → Rollback → Run workflow
# Input: 20241130_020000
```

**Duración**: ~2-5 minutos

---

## Uso Diario

### Flujo de Desarrollo

```bash
# 1. Crear branch para nueva feature
git checkout -b feature/nueva-funcionalidad

# 2. Hacer cambios
# ... editar código ...

# 3. Commit y push
git add .
git commit -m "Add nueva funcionalidad"
git push origin feature/nueva-funcionalidad

# → Trigger: validate-config.yml (automático)

# 4. Crear Pull Request
gh pr create --title "Nueva funcionalidad" --body "Descripción"

# → Trigger: validate-config.yml (automático en PR)

# 5. Review y merge
gh pr merge --squash

# 6. Deploy a producción
git checkout main
git pull
gh release create v1.1.0 --title "Release v1.1.0" --notes "- Nueva funcionalidad"

# → Trigger: deploy-production.yml (automático)
```

### Monitoreo de Workflows

```bash
# Ver workflows activos
gh run list

# Ver logs en vivo
gh run watch

# Ver logs de workflow específico
gh run view RUN_ID --log

# Listar runners
gh api /repos/OWNER/REPO/actions/runners
```

### Backups

```bash
# Ejecutar backup manual
gh workflow run backup-database.yml

# Ver backups disponibles
ssh usuario@vps
ls -lh /backups/odoo/
```

### Rollback

```bash
# 1. Ver backups disponibles
ssh usuario@vps
ls /backups/odoo/

# Ejemplo de output:
# odoo_backup_20241130_020000.sql.gz
# odoo_backup_20241129_020000.sql.gz

# 2. Ejecutar rollback
gh workflow run rollback.yml -f backup_date=20241130_020000

# 3. Monitorear
gh run watch
```

---

## Troubleshooting

### Workflow no se ejecuta

**Síntomas**: Creas release pero no se ejecuta deployment

**Diagnóstico**:
```bash
# Verificar runner está online
gh api /repos/OWNER/REPO/actions/runners

# Ver workflows
gh workflow list

# Ver runs fallidos
gh run list --status failure
```

**Solución**:
```bash
# En VPS
sudo systemctl status actions.runner.*
sudo systemctl restart actions.runner.*
```

---

### Deployment falla con "Secret not found"

**Síntomas**: Workflow falla diciendo que falta un secret

**Diagnóstico**:
```bash
# Listar secrets
gh secret list

# Ver logs del workflow
gh run view --log
```

**Solución**:
```bash
# Agregar secret faltante
gh secret set SECRET_NAME -b "value"

# O ejecutar script
./setup-github-secrets.sh
```

---

### Health check timeout

**Síntomas**: Deployment falla en "Wait for services to be healthy"

**Diagnóstico**:
```bash
# Ver logs de Odoo en VPS
ssh usuario@vps
cd /home/geniusdev/WorkSpace/odoo
docker compose logs odoo --tail=50
```

**Solución**:
```bash
# Aumentar timeout en workflow
# Editar .github/workflows/deploy-production.yml
max_attempts=60  # Cambiar de 30 a 60
```

---

### Runner offline

**Síntomas**: Workflow queda en "Waiting for a runner"

**Diagnóstico**:
```bash
# En VPS
sudo systemctl status actions.runner.*
```

**Solución**:
```bash
# Reiniciar servicio
sudo systemctl restart actions.runner.*

# Ver logs
sudo journalctl -u actions.runner.* -f
```

---

## Checklist de Setup

- [ ] **Runner configurado en VPS**
  - [ ] Usuario github-runner creado
  - [ ] Runner descargado y configurado
  - [ ] Servicio instalado y corriendo
  - [ ] Aparece como "Idle" en GitHub

- [ ] **Secrets configurados en GitHub**
  - [ ] DOMAIN
  - [ ] ODOO_VERSION
  - [ ] ACME_EMAIL
  - [ ] TRAEFIK_DASHBOARD_AUTH
  - [ ] POSTGRES_PASSWORD
  - [ ] TZ

- [ ] **Workflows pusheados**
  - [ ] .github/workflows/ en repositorio
  - [ ] Workflow de validación pasa

- [ ] **Testing**
  - [ ] Test workflow ejecutado exitosamente
  - [ ] Deployment manual exitoso
  - [ ] Backup manual exitoso

- [ ] **Producción**
  - [ ] Deployment con release exitoso
  - [ ] Odoo accesible en https://odoo.DOMAIN
  - [ ] Backups automáticos funcionando

---

## Comandos de Referencia Rápida

```bash
# WORKFLOWS
gh workflow list                           # Listar workflows
gh workflow run WORKFLOW_NAME             # Ejecutar workflow
gh run list                               # Listar runs
gh run watch                              # Ver run en vivo
gh run view RUN_ID --log                  # Ver logs

# RELEASES
gh release create v1.0.0 --title "..."    # Crear release
gh release list                           # Listar releases

# SECRETS
gh secret list                            # Listar secrets
gh secret set NAME -b "value"             # Configurar secret
./setup-github-secrets.sh                 # Script automático

# RUNNER (en VPS)
sudo systemctl status actions.runner.*    # Ver estado
sudo systemctl restart actions.runner.*   # Reiniciar
sudo journalctl -u actions.runner.* -f   # Ver logs

# DOCKER (en VPS)
cd /home/geniusdev/WorkSpace/odoo
docker compose ps                         # Ver containers
docker compose logs -f                    # Ver logs
```

---

## Arquitectura de Archivos

```
odoo/
├── .github/
│   ├── workflows/
│   │   ├── deploy-production.yml    # Deployment automático
│   │   ├── validate-config.yml      # Validación CI
│   │   ├── backup-database.yml      # Backups automáticos
│   │   └── rollback.yml             # Rollback manual
│   ├── README.md                    # Overview de CI/CD
│   ├── SECRETS.md                   # Guía de secrets
│   ├── RUNNER_SETUP.md              # Guía de runner
│   └── WORKFLOWS.md                 # Documentación técnica
├── docker-compose.yml               # Config de servicios
├── .env                             # Variables de entorno
├── setup-github-secrets.sh          # Script helper
└── CI_CD_GUIDE.md                   # Esta guía
```

---

## Referencias

- **Setup Runner**: [`.github/RUNNER_SETUP.md`](.github/RUNNER_SETUP.md)
- **Configurar Secrets**: [`.github/SECRETS.md`](.github/SECRETS.md)
- **Documentación de Workflows**: [`.github/WORKFLOWS.md`](.github/WORKFLOWS.md)
- **Deployment Manual**: [`DEPLOYMENT.md`](DEPLOYMENT.md)
- **Quick Start**: [`QUICK_START.md`](QUICK_START.md)

---

**Estado**: ✅ CI/CD completamente configurado y documentado

**Última actualización**: 2024-11-30
