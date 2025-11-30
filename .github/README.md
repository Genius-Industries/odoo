# GitHub Actions CI/CD

Configuración completa de CI/CD con GitHub Actions para deployment automático de Odoo.

---

## 📋 Workflows Disponibles

### 1. `deploy-production.yml`
**Trigger**: Release publicado o manual

**Función**: Deploy automático a producción

**Características**:
- ✅ Build y deploy de containers
- ✅ Health checks automáticos
- ✅ Rollback automático si falla
- ✅ Limpieza de imágenes antiguas
- ✅ Notificaciones de deployment

**Uso**:
```bash
# Automático: Crear release en GitHub
gh release create v1.0.0 --title "Production Release v1.0.0"

# Manual: GitHub UI
Actions → Deploy to Production → Run workflow
```

---

### 2. `validate-config.yml`
**Trigger**: Push o PR a main/master/develop

**Función**: Validar configuración antes de merge

**Validaciones**:
- ✅ Sintaxis de docker-compose.yml
- ✅ Archivos requeridos presentes
- ✅ Variables de entorno definidas
- ✅ Configuración de red consistente

**Uso**: Se ejecuta automáticamente en cada push/PR

---

### 3. `backup-database.yml`
**Trigger**: Cron diario (2 AM UTC) o manual

**Función**: Backup automático de PostgreSQL

**Características**:
- ✅ Backup completo de base de datos
- ✅ Compresión automática
- ✅ Verificación de integridad
- ✅ Limpieza de backups antiguos (mantiene últimos 7)
- ✅ Almacenamiento en `/backups/odoo/`

**Uso**:
```bash
# Manual desde GitHub UI
Actions → Backup Database → Run workflow

# Ver backups
ssh usuario@vps
ls -lh /backups/odoo/
```

---

### 4. `rollback.yml`
**Trigger**: Manual con input de fecha

**Función**: Restaurar base de datos desde backup

**Uso**:
```bash
# Desde GitHub UI
Actions → Rollback Deployment → Run workflow
# Ingresar fecha del backup (formato: YYYYMMDD_HHMMSS)
```

**Ejemplo**:
```
Backup date: 20241130_020000
```

---

## 🚀 Setup Inicial

### Paso 1: Configurar Self-Hosted Runner

Ver guía completa: [`RUNNER_SETUP.md`](./RUNNER_SETUP.md)

**Resumen**:
```bash
# En tu VPS
sudo useradd -m -s /bin/bash github-runner
sudo usermod -aG docker github-runner

# Descargar y configurar runner
# (seguir instrucciones de GitHub Settings → Actions → Runners)

# Instalar como servicio
sudo ./svc.sh install github-runner
sudo ./svc.sh start
```

### Paso 2: Configurar GitHub Secrets

Ver guía completa: [`SECRETS.md`](./SECRETS.md)

**Secrets requeridos**:
```
DOMAIN                   → geniusindustries.org
ODOO_VERSION            → 19.0
ACME_EMAIL              → admin@geniusindustries.org
TRAEFIK_DASHBOARD_AUTH  → admin:$$apr1$$...
POSTGRES_PASSWORD       → [password seguro]
TZ                      → America/Bogota
```

**Configurar en GitHub**:
```
Settings → Secrets and variables → Actions → New repository secret
```

### Paso 3: Test

```bash
# Ejecutar workflow de validación
git add .
git commit -m "Setup GitHub Actions"
git push

# Verificar en GitHub
# Actions → Validate Configuration (debería pasar)
```

---

## 📊 Workflow de Deployment

```
1. Developer crea release
         │
         ▼
2. Trigger workflow deploy-production.yml
         │
         ▼
3. Self-hosted runner ejecuta:
   - Checkout código
   - Setup .env con secrets
   - Validar config
   - Pull/Build images
   - Deploy con docker compose
   - Health checks
         │
         ▼
4. Si todo OK:
   ✓ Deployment completado
   ✓ Odoo corriendo en https://odoo.DOMAIN
   │
   Si falla:
   ✗ Rollback automático
   ✗ Notificación de error
```

---

## 🔐 Seguridad

### ✅ Implementado

- ✅ Secrets no expuestos en logs
- ✅ Runner en servidor privado
- ✅ Validación de configuración antes de deploy
- ✅ Health checks antes de considerar deployment exitoso
- ✅ Backups automáticos diarios
- ✅ Rollback manual disponible

### 🔒 Recomendaciones Adicionales

1. **Proteger rama main**:
   ```
   Settings → Branches → Add rule
   - Require pull request reviews
   - Require status checks to pass
   ```

2. **Limitar acceso al runner**:
   ```bash
   # Solo permitir workflows específicos
   # Settings → Actions → Runner groups → Default
   ```

3. **Auditar logs**:
   ```bash
   # En VPS
   sudo journalctl -u actions.runner.* -f
   ```

---

## 📈 Monitoring

### Ver Estado de Workflows

**GitHub UI**:
```
Actions → [Workflow Name] → [Run]
```

**GitHub CLI**:
```bash
# Listar workflows
gh workflow list

# Ver runs de un workflow
gh run list --workflow=deploy-production.yml

# Ver logs de último run
gh run view --log
```

### Ver Estado del Runner

**GitHub UI**:
```
Settings → Actions → Runners
```

**VPS**:
```bash
# Estado del servicio
sudo systemctl status actions.runner.*

# Logs en vivo
sudo journalctl -u actions.runner.* -f
```

---

## 🛠️ Troubleshooting

### Workflow falla con "Runner not found"

**Causa**: Runner offline o no configurado

**Solución**:
```bash
# En VPS
sudo systemctl status actions.runner.*
sudo systemctl restart actions.runner.*
```

### Workflow falla con "Secret not found"

**Causa**: Secret no configurado en GitHub

**Solución**:
```bash
# Verificar secrets
gh secret list

# Agregar secret faltante
gh secret set SECRET_NAME -b "value"
```

### Deployment falla con "Permission denied"

**Causa**: Runner no tiene permisos Docker

**Solución**:
```bash
# En VPS
sudo usermod -aG docker github-runner
sudo systemctl restart actions.runner.*
```

### Health check timeout

**Causa**: Odoo tarda en iniciar

**Solución**: Aumentar timeout en workflow:
```yaml
- name: Wait for services
  run: |
    max_attempts=60  # Aumentar de 30 a 60
```

---

## 📚 Archivos de Referencia

| Archivo | Descripción |
|---------|-------------|
| `workflows/deploy-production.yml` | Workflow de deployment |
| `workflows/validate-config.yml` | Workflow de validación |
| `workflows/backup-database.yml` | Workflow de backups |
| `workflows/rollback.yml` | Workflow de rollback |
| `SECRETS.md` | Guía de configuración de secrets |
| `RUNNER_SETUP.md` | Guía de instalación del runner |
| `WORKFLOWS.md` | Documentación detallada de workflows |

---

## 🎯 Flujo de Trabajo Recomendado

### Development

```bash
# 1. Crear branch
git checkout -b feature/nueva-funcionalidad

# 2. Hacer cambios
# ... editar código ...

# 3. Commit y push
git add .
git commit -m "Add nueva funcionalidad"
git push origin feature/nueva-funcionalidad

# 4. Crear PR
gh pr create --title "Nueva funcionalidad" --body "Descripción"

# → Trigger: validate-config.yml (automático)
```

### Staging (Opcional)

```bash
# 1. Merge a develop
git checkout develop
git merge feature/nueva-funcionalidad
git push

# → Trigger: validate-config.yml (automático)
```

### Production

```bash
# 1. Merge a main
git checkout main
git merge develop
git push

# 2. Crear release
gh release create v1.0.0 \
  --title "Production Release v1.0.0" \
  --notes "- Nueva funcionalidad"

# → Trigger: deploy-production.yml (automático)
```

---

## 📝 Checklist de Setup

- [ ] Self-hosted runner instalado en VPS
- [ ] Runner aparece como "Idle" en GitHub
- [ ] Todos los secrets configurados
- [ ] Workflow de validación pasa
- [ ] Test manual de deployment exitoso
- [ ] Backups automáticos configurados
- [ ] Rollback testeado (opcional pero recomendado)
- [ ] Monitoring configurado
- [ ] Documentación revisada por el equipo

---

## 🔄 Actualización de Workflows

Para actualizar workflows:

```bash
# 1. Editar workflow
nano .github/workflows/deploy-production.yml

# 2. Commit y push
git add .github/workflows/
git commit -m "Update deployment workflow"
git push

# 3. Los cambios se aplican inmediatamente
```

**Nota**: Los workflows se leen del branch donde se ejecutan, no del default branch.

---

## 📞 Soporte

**Problemas con workflows**:
1. Revisar logs en GitHub Actions
2. Revisar logs del runner en VPS
3. Verificar secrets configurados
4. Consultar `RUNNER_SETUP.md` y `SECRETS.md`

**Comandos útiles**:
```bash
# GitHub CLI
gh workflow list
gh run list
gh run view --log

# En VPS
sudo journalctl -u actions.runner.* -f
docker compose logs -f
```

---

**Estado**: ✅ CI/CD completamente configurado

**Última actualización**: 2024-11-30
