# GitHub Secrets Configuration

Esta guía explica cómo configurar los secrets necesarios en GitHub para que los workflows funcionen correctamente.

## Acceder a Secrets en GitHub

1. Ve a tu repositorio en GitHub
2. Click en `Settings` → `Secrets and variables` → `Actions`
3. Click en `New repository secret`

---

## Secrets Requeridos

### 1. `DOMAIN`
**Descripción**: Dominio principal de tu aplicación (sin subdominios)

**Valor de ejemplo**:
```
geniusindustries.org
```

**Uso**: Se usa para construir las URLs de Odoo y Traefik
- `odoo.${DOMAIN}` → `odoo.geniusindustries.org`
- `traefik.${DOMAIN}` → `traefik.geniusindustries.org`

---

### 2. `ODOO_VERSION`
**Descripción**: Versión de Odoo a usar

**Valor de ejemplo**:
```
19.0
```

**Opciones válidas**: `17.0`, `18.0`, `19.0`

---

### 3. `ACME_EMAIL`
**Descripción**: Email para Let's Encrypt (certificados SSL)

**Valor de ejemplo**:
```
admin@geniusindustries.org
```

**Importante**: Let's Encrypt enviará notificaciones de renovación a este email.

---

### 4. `TRAEFIK_DASHBOARD_AUTH`
**Descripción**: Credenciales de autenticación básica para el dashboard de Traefik

**Cómo generarlo**:

```bash
# Opción 1: Con htpasswd (recomendado)
echo $(htpasswd -nb admin tu_password) | sed -e s/\\$/\\$\\$/g

# Opción 2: Online
# Visita: https://hostingcanada.org/htpasswd-generator/
# IMPORTANTE: Reemplaza $ por $$ en el resultado
```

**Valor de ejemplo**:
```
admin:$$apr1$$8g1nh0jm$$RGQwWvGMzjP3PsLd7qVe21
```

**Nota**: Los `$$` (doble dollar) son necesarios para escapar el carácter en GitHub Actions.

---

### 5. `POSTGRES_PASSWORD`
**Descripción**: Password para PostgreSQL

**Cómo generarlo**:
```bash
openssl rand -base64 32
```

**Valor de ejemplo**:
```
X7k9mPqL2vN8jRwT3yH6bF4sC1dE5gA9
```

**Seguridad**:
- Mínimo 16 caracteres
- Incluir mayúsculas, minúsculas, números y símbolos
- No usar palabras del diccionario

---

### 6. `TZ` (Opcional)
**Descripción**: Zona horaria para los containers

**Valor de ejemplo**:
```
America/Bogota
```

**Zonas horarias comunes**:
- `America/New_York`
- `America/Chicago`
- `America/Los_Angeles`
- `Europe/Madrid`
- `Europe/London`

**Ver todas**: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

---

## Cómo Agregar Secrets

### Método 1: GitHub UI (Recomendado)

1. **Ir a Settings**:
   ```
   Tu Repositorio → Settings → Secrets and variables → Actions
   ```

2. **Agregar cada secret**:
   - Click en `New repository secret`
   - Name: `DOMAIN`
   - Value: `geniusindustries.org`
   - Click en `Add secret`

3. **Repetir para cada secret** listado arriba

### Método 2: GitHub CLI

```bash
# Instalar GitHub CLI si no lo tienes
# https://cli.github.com/

# Autenticarte
gh auth login

# Agregar secrets
gh secret set DOMAIN -b "geniusindustries.org"
gh secret set ODOO_VERSION -b "19.0"
gh secret set ACME_EMAIL -b "admin@geniusindustries.org"
gh secret set TRAEFIK_DASHBOARD_AUTH -b "admin:\$\$apr1\$\$..."
gh secret set POSTGRES_PASSWORD -b "$(openssl rand -base64 32)"
gh secret set TZ -b "America/Bogota"
```

---

## Verificar Secrets Configurados

### GitHub UI

1. Ve a `Settings` → `Secrets and variables` → `Actions`
2. Deberías ver todos los secrets listados (sin ver sus valores)

### GitHub CLI

```bash
gh secret list
```

**Output esperado**:
```
ACME_EMAIL               Updated 2024-11-30
DOMAIN                   Updated 2024-11-30
ODOO_VERSION            Updated 2024-11-30
POSTGRES_PASSWORD       Updated 2024-11-30
TRAEFIK_DASHBOARD_AUTH  Updated 2024-11-30
TZ                      Updated 2024-11-30
```

---

## Environment-Specific Secrets (Avanzado)

Si quieres tener diferentes secrets para staging y producción:

### 1. Crear Environments

```
Settings → Environments → New environment
```

Crea:
- `production`
- `staging`

### 2. Agregar Secrets al Environment

En cada environment, agrega los secrets específicos:

**Production**:
- `DOMAIN` = `geniusindustries.org`

**Staging**:
- `DOMAIN` = `staging.geniusindustries.org`

### 3. Usar en Workflows

```yaml
jobs:
  deploy:
    environment: production  # o staging
```

---

## Seguridad de Secrets

### ✅ Buenas Prácticas

1. **Nunca commits secrets en código**
   - Usa `.gitignore` para archivos sensibles
   - Revisa commits antes de push

2. **Rota secrets regularmente**
   - Cambia passwords cada 90 días
   - Actualiza secrets en GitHub cuando cambies

3. **Principio de mínimo privilegio**
   - Solo agrega secrets necesarios
   - Usa environment-specific secrets cuando sea posible

4. **Audita acceso**
   - Revisa quién tiene acceso al repositorio
   - Limita acceso a Settings

### ❌ Evitar

1. ❌ No hacer echo de secrets en logs
   ```yaml
   # MAL
   - run: echo "Password is ${{ secrets.POSTGRES_PASSWORD }}"

   # BIEN
   - run: echo "Password configured"
   ```

2. ❌ No usar secrets en PRs de forks
   - GitHub no expone secrets a PRs de forks por seguridad

3. ❌ No usar valores por defecto débiles
   - No uses `admin`, `password123`, etc.

---

## Testing de Secrets

Para verificar que los secrets funcionan sin exponerlos:

```yaml
- name: Verify secrets are set
  run: |
    echo "Checking secrets..."

    if [ -z "${{ secrets.DOMAIN }}" ]; then
      echo "✗ DOMAIN secret is not set"
      exit 1
    fi
    echo "✓ DOMAIN is set"

    if [ -z "${{ secrets.POSTGRES_PASSWORD }}" ]; then
      echo "✗ POSTGRES_PASSWORD secret is not set"
      exit 1
    fi
    echo "✓ POSTGRES_PASSWORD is set"

    # Repetir para cada secret...
```

---

## Troubleshooting

### "Secret not found"

**Problema**: Workflow falla con mensaje sobre secret no encontrado

**Solución**:
1. Verifica que el nombre del secret esté bien escrito (case-sensitive)
2. Verifica que el secret existe en `Settings → Secrets`
3. Si usas environments, verifica que el secret esté en el environment correcto

### "Invalid secret format"

**Problema**: Secret tiene formato incorrecto (ej: `TRAEFIK_DASHBOARD_AUTH`)

**Solución**:
1. Verifica que usaste `$$` en lugar de `$` para escapar
2. Regenera el hash de password correctamente

### "Cannot access secrets in fork"

**Problema**: PR desde fork no puede acceder a secrets

**Solución**:
- Esto es comportamiento esperado por seguridad
- Los maintainers deben hacer merge primero
- O ejecutar workflow manualmente después del merge

---

## Script Helper para Configurar Secrets

Guarda este script como `setup-github-secrets.sh`:

```bash
#!/bin/bash

echo "GitHub Secrets Setup Helper"
echo "============================"
echo ""

# Verificar gh CLI
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI no encontrado. Instálalo desde: https://cli.github.com/"
    exit 1
fi

# Autenticación
echo "Verificando autenticación..."
gh auth status || gh auth login

# DOMAIN
read -p "Enter DOMAIN (e.g., geniusindustries.org): " domain
gh secret set DOMAIN -b "$domain"

# ODOO_VERSION
read -p "Enter ODOO_VERSION (17.0, 18.0, 19.0): " odoo_version
gh secret set ODOO_VERSION -b "$odoo_version"

# ACME_EMAIL
read -p "Enter ACME_EMAIL: " acme_email
gh secret set ACME_EMAIL -b "$acme_email"

# POSTGRES_PASSWORD
echo "Generating POSTGRES_PASSWORD..."
postgres_pass=$(openssl rand -base64 32)
gh secret set POSTGRES_PASSWORD -b "$postgres_pass"
echo "Password generated and saved"

# TZ
read -p "Enter TZ (e.g., America/Bogota): " tz
gh secret set TZ -b "$tz"

# TRAEFIK_DASHBOARD_AUTH
echo ""
echo "For TRAEFIK_DASHBOARD_AUTH, generate it at:"
echo "https://hostingcanada.org/htpasswd-generator/"
echo "Remember to replace \$ with \$\$"
read -p "Enter TRAEFIK_DASHBOARD_AUTH: " traefik_auth
gh secret set TRAEFIK_DASHBOARD_AUTH -b "$traefik_auth"

echo ""
echo "✓ All secrets configured!"
echo ""
echo "Verify with: gh secret list"
```

Ejecutar:
```bash
chmod +x setup-github-secrets.sh
./setup-github-secrets.sh
```

---

## Resumen

**Secrets mínimos requeridos**:
1. ✅ `DOMAIN`
2. ✅ `ODOO_VERSION`
3. ✅ `ACME_EMAIL`
4. ✅ `TRAEFIK_DASHBOARD_AUTH`
5. ✅ `POSTGRES_PASSWORD`
6. ⚠️ `TZ` (opcional, por defecto UTC)

**Total**: 5-6 secrets

Una vez configurados, los workflows podrán ejecutarse automáticamente con deployment seguro.
