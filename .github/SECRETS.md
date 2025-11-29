# GitHub Secrets Configuration

Este documento describe cómo configurar los secrets necesarios para los workflows de GitHub Actions.

## 📋 Secrets Requeridos

### 🔐 Server Access (Obligatorios)

| Secret | Descripción | Ejemplo | Cómo obtener |
|--------|-------------|---------|--------------|
| `SSH_HOST` | IP o dominio del servidor de producción | `123.45.67.89` o `server.example.com` | Tu proveedor de hosting |
| `SSH_USER` | Usuario SSH con permisos | `deploy` o `root` | Crear usuario dedicado recomendado |
| `SSH_PRIVATE_KEY` | Llave privada SSH (completa) | `-----BEGIN OPENSSH PRIVATE KEY-----` | Ver sección "Generar SSH Key" |

### 🌐 Environment Variables (Obligatorios)

| Secret | Descripción | Ejemplo | Cómo obtener |
|--------|-------------|---------|--------------|
| `DOMAIN` | Dominio de producción | `odoo.geniusindustries.org` | Tu dominio registrado |
| `ACME_EMAIL` | Email para Let's Encrypt | `admin@geniusindustries.org` | Email válido del administrador |
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL | `SuperSecurePass123!` | Generar contraseña segura |
| `TRAEFIK_DASHBOARD_AUTH` | Auth hash para Traefik | `admin:$$apr1$$xyz$$abc` | Ver sección "Generar Auth Hash" |

### ☁️ Backup Storage (Opcionales - Solo si usas S3)

| Secret | Descripción | Ejemplo | Cómo obtener |
|--------|-------------|---------|--------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key | `AKIAIOSFODNN7EXAMPLE` | AWS IAM Console |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | `wJalrXUtnFEMI/K7MDENG/...` | AWS IAM Console |
| `BACKUP_BUCKET` | Nombre del bucket S3 | `odoo-backups-prod` | Crear bucket en S3 |

## 🔧 Configuración Paso a Paso

### 1. Generar SSH Key

En tu máquina local:

```bash
# Generar nueva llave SSH dedicada para deployment
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy_key

# Copiar llave pública al servidor
ssh-copy-id -i ~/.ssh/github_deploy_key.pub user@your-server.com

# Mostrar llave privada (para copiar al secret)
cat ~/.ssh/github_deploy_key
```

**IMPORTANTE**: Copia TODO el contenido de la llave privada, incluyendo:
- `-----BEGIN OPENSSH PRIVATE KEY-----`
- Todo el contenido
- `-----END OPENSSH PRIVATE KEY-----`

### 2. Generar Hash de Autenticación Traefik

Opción A - Usando htpasswd (local):
```bash
# Instalar apache2-utils si no lo tienes
sudo apt-get install apache2-utils

# Generar hash (reemplaza 'admin' y 'tu_password')
echo $(htpasswd -nb admin tu_password) | sed -e s/\\$/\\$\\$/g
```

Opción B - Usando generador online:
1. Ir a: https://hostingcanada.org/htpasswd-generator/
2. Usuario: `admin`
3. Password: `tu_password_seguro`
4. Copiar el hash generado
5. **IMPORTANTE**: Duplicar cada signo `$` → `$$` para docker-compose

Ejemplo:
- Hash original: `admin:$apr1$xyz$abc`
- Hash para secret: `admin:$$apr1$$xyz$$abc`

### 3. Configurar Secrets en GitHub

#### Método Web UI:

1. Ve a tu repositorio en GitHub
2. Click en `Settings` → `Secrets and variables` → `Actions`
3. Click en `New repository secret`
4. Para cada secret:
   - Nombre: Exactamente como aparece en la tabla (ej: `SSH_HOST`)
   - Valor: El valor correspondiente
   - Click en `Add secret`

#### Método GitHub CLI:

```bash
# Instalar GitHub CLI si no lo tienes
# https://cli.github.com/

# Login
gh auth login

# Configurar secrets
gh secret set SSH_HOST --body "123.45.67.89"
gh secret set SSH_USER --body "deploy"
gh secret set SSH_PRIVATE_KEY < ~/.ssh/github_deploy_key
gh secret set DOMAIN --body "odoo.geniusindustries.org"
gh secret set ACME_EMAIL --body "admin@geniusindustries.org"
gh secret set POSTGRES_PASSWORD --body "SuperSecurePass123!"
gh secret set TRAEFIK_DASHBOARD_AUTH --body 'admin:$$apr1$$xyz$$abc'
```

### 4. Configurar Environment (Opcional pero Recomendado)

Para mayor seguridad, configura un environment de producción:

1. Ve a `Settings` → `Environments`
2. Click en `New environment`
3. Nombre: `production`
4. Configurar:
   - ✅ Required reviewers (opcional): Requiere aprobación manual
   - ✅ Wait timer (opcional): Espera X minutos antes de deploy
   - ✅ Deployment branches: Solo desde `main`

Los secrets de environment tienen precedencia sobre los del repositorio.

## 🧪 Verificar Configuración

### Opción 1: Workflow de Testing

```bash
# Los workflows de CI se ejecutarán automáticamente en PRs
# Crear un PR de prueba para validar la configuración
git checkout -b test/verify-workflows
git push origin test/verify-workflows
# Crear PR en GitHub
```

### Opción 2: Workflow Manual

1. Ve a `Actions` en GitHub
2. Selecciona `Maintenance & Monitoring`
3. Click en `Run workflow`
4. Selecciona `health-check`
5. Click en `Run workflow`

Si todo está configurado correctamente, el workflow debería:
- ✅ Conectar por SSH
- ✅ Verificar servicios
- ✅ Completar sin errores

## 🔒 Mejores Prácticas de Seguridad

### SSH Key Management

- ✅ **Usar llave dedicada**: Crea una llave específica para GitHub Actions
- ✅ **Permisos mínimos**: El usuario SSH solo debe tener acceso a `/opt/odoo`
- ✅ **Rotar llaves**: Cambia las llaves periódicamente (cada 90 días)
- ❌ **No reutilizar**: No uses tu llave personal SSH

### Password Security

- ✅ **Contraseñas fuertes**: Mínimo 16 caracteres, mixtos
- ✅ **Unique passwords**: Diferente para cada servicio
- ✅ **Password manager**: Usa 1Password, Bitwarden, etc.
- ❌ **No compartir**: Los secrets son secretos, no los compartas

### Ejemplo de creación de usuario dedicado:

```bash
# En el servidor de producción
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Crear directorio .ssh
sudo mkdir -p /home/deploy/.ssh
sudo touch /home/deploy/.ssh/authorized_keys
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys

# Agregar la llave pública
echo "ssh-ed25519 AAAA... github-actions-deploy" | sudo tee -a /home/deploy/.ssh/authorized_keys

# Configurar ownership
sudo chown -R deploy:deploy /home/deploy/.ssh

# Dar permisos sudo solo para docker (opcional)
echo "deploy ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee /etc/sudoers.d/deploy
```

## 🐛 Troubleshooting

### Error: "Permission denied (publickey)"

**Causa**: La llave SSH no está configurada correctamente.

**Solución**:
1. Verifica que copiaste la llave PRIVADA completa al secret `SSH_PRIVATE_KEY`
2. Verifica que la llave PÚBLICA está en `~/.ssh/authorized_keys` del servidor
3. Verifica permisos: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`

### Error: "Host key verification failed"

**Causa**: El servidor no está en known_hosts.

**Solución**: Los workflows ya incluyen `ssh-keyscan`, pero verifica que `SSH_HOST` sea correcto.

### Error: Traefik dashboard auth failed

**Causa**: Hash de autenticación mal formado.

**Solución**: Asegúrate de duplicar todos los `$` → `$$` en el hash.

### Workflow no se ejecuta

**Causa**: Permisos de Actions no configurados.

**Solución**:
1. Ve a `Settings` → `Actions` → `General`
2. En "Workflow permissions": Selecciona "Read and write permissions"
3. ✅ "Allow GitHub Actions to create and approve pull requests"

## 📚 Referencias

- [GitHub Actions - Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [SSH Key Authentication](https://www.ssh.com/academy/ssh/key)
- [htpasswd Generator](https://hostingcanada.org/htpasswd-generator/)

## 🆘 Soporte

Si tienes problemas:

1. **Revisa los logs**: `Actions` → Selecciona el workflow fallido → Ver logs detallados
2. **Verifica secrets**: Revisa que todos los secrets obligatorios estén configurados
3. **Test local**: Prueba la conexión SSH manualmente desde tu máquina
4. **Issues**: Abre un issue en el repositorio con los logs (sin secrets!)

---

**Última actualización**: 2025-11-30
