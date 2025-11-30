# Quick Start - Odoo en VPS

## Pre-requisitos (5 min)

```bash
# 1. DNS configurado
nslookup odoo.geniusindustries.org  # Debe apuntar a tu VPS

# 2. Docker instalado
docker --version
docker compose version

# 3. Puertos abiertos
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## Instalación (2 min)

```bash
# 1. Ir al directorio del proyecto
cd /home/geniusdev/WorkSpace/odoo

# 2. Ejecutar setup
chmod +x setup.sh
./setup.sh

# Responder 'y' cuando pregunte si iniciar servicios
```

## Verificación (1 min)

```bash
# Ver que todo esté corriendo
docker compose ps

# Deberías ver 3 containers:
# - traefik (running)
# - odoo-web (running)
# - odoo-db (healthy)
```

## Acceso

Espera 1-2 minutos para que se generen los certificados SSL, luego:

- **Odoo**: https://odoo.geniusindustries.org
- **Traefik Dashboard**: https://traefik.geniusindustries.org
  - Usuario: `admin`
  - Password: (ver en `.env` → `TRAEFIK_DASHBOARD_AUTH`)

## Troubleshooting Rápido

### Error: "Network not found"
```bash
docker network create traefik-public
docker compose up -d
```

### Error: "Cannot obtain certificate"
```bash
# Verifica DNS
nslookup odoo.geniusindustries.org

# Verifica puertos
sudo netstat -tulpn | grep -E '80|443'

# Ver logs
docker compose logs traefik | grep acme
```

### Error 502 Bad Gateway
```bash
# Ver logs de Odoo
docker compose logs odoo

# Reiniciar Odoo
docker compose restart odoo
```

## Comandos Útiles

```bash
# Ver logs en vivo
docker compose logs -f

# Reiniciar todo
docker compose restart

# Detener todo
docker compose down

# Backup rápido de BD
docker compose exec db pg_dumpall -U odoo > backup.sql
```

## Configuración Post-Instalación

### Primera vez en Odoo:
1. Ir a: https://odoo.geniusindustries.org
2. Crear base de datos:
   - Master Password: `admin_change_this_password`
   - Database Name: `production`
   - Email: tu-email@geniusindustries.org
   - Language: Spanish
   - Country: Colombia

### Cambiar passwords de seguridad:
```bash
# 1. Password de PostgreSQL
nano odoo_pg_pass
# Cambiar por password seguro
docker compose down
docker compose up -d

# 2. Password de Traefik Dashboard
nano .env
# Cambiar TRAEFIK_DASHBOARD_AUTH
docker compose restart traefik

# 3. Password de Odoo Admin
nano config/odoo.conf
# Cambiar admin_passwd
docker compose restart odoo
```

## Listo

Tu Odoo está corriendo en producción con SSL automático.

Para más detalles, ver:
- `README.md` - Documentación completa
- `DEPLOYMENT.md` - Guía de deployment detallada
