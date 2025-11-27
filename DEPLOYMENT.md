# Guía de Deployment Odoo con Traefik

Esta guía te ayudará a desplegar Odoo con Traefik como reverse proxy, SSL automático y soporte para módulos OCA.

## Prerequisitos

- Docker y Docker Compose instalados
- Dominio apuntando a tu servidor (A record en DNS)
- Puerto 80 y 443 abiertos en firewall
- (Opcional) Cuenta de Cloudflare si usas DNS challenge

## Estructura del Proyecto

```
odoo/
├── docker-compose.yml              # Servicios principales (Odoo + PostgreSQL)
├── docker-compose.traefik.yml      # Traefik reverse proxy
├── .env                            # Variables de entorno (crear desde .env.example)
├── addons/                         # Módulos OCA personalizados
├── config/
│   └── odoo.conf                   # Configuración de Odoo
└── traefik/
    ├── traefik.yml                 # Configuración estática de Traefik
    ├── acme.json                   # Certificados SSL (auto-generado)
    └── dynamic/
        └── middlewares.yml         # Middlewares de seguridad
```

## Configuración Inicial

### 1. Configurar variables de entorno

```bash
cp .env.example .env
nano .env
```

Configura las siguientes variables:

```env
# Tu dominio
DOMAIN=tudominio.com

# Versión de Odoo
ODOO_VERSION=17.0

# Base de datos
POSTGRES_PASSWORD=un_password_muy_seguro

# Email para Let's Encrypt
ACME_EMAIL=tu-email@example.com

# Cloudflare (solo si usas DNS challenge)
CF_API_EMAIL=tu-email@cloudflare.com
CF_DNS_API_TOKEN=tu_token_cloudflare
```

### 2. Generar autenticación para Dashboard Traefik

```bash
# Instalar htpasswd si no lo tienes
sudo apt-get install apache2-utils

# Generar usuario y password (cambiar 'admin' y 'tupassword')
echo $(htpasswd -nb admin tupassword) | sed -e s/\\$/\\$\\$/g

# Copiar el resultado en .env como TRAEFIK_DASHBOARD_AUTH
```

### 3. Configurar DNS

Apunta tu dominio a la IP de tu servidor:

```
# En tu proveedor DNS (Cloudflare, etc.)
A     @              tu.ip.del.servidor
A     traefik        tu.ip.del.servidor
```

## Deployment

### Opción 1: Usar HTTP Challenge (recomendado para servidores públicos)

En `traefik/traefik.yml`, comenta `dnsChallenge` y descomenta `httpChallenge`:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: acme.json
      httpChallenge:
        entryPoint: web
```

### Opción 2: Usar DNS Challenge (recomendado para Cloudflare)

Mantén la configuración actual en `traefik/traefik.yml` y asegúrate de tener configurado:

```env
CF_API_EMAIL=tu-email@cloudflare.com
CF_DNS_API_TOKEN=tu_token_cloudflare
```

### Iniciar servicios

```bash
# Crear la red de Traefik
docker network create traefik-network

# Iniciar Traefik
docker compose -f docker-compose.traefik.yml up -d

# Verificar logs de Traefik
docker logs -f traefik

# Iniciar Odoo y PostgreSQL
docker compose up -d

# Verificar logs de Odoo
docker logs -f odoo_app
```

## Verificación

1. **Dashboard de Traefik**: https://traefik.tudominio.com
   - Usuario: admin (o el que configuraste)
   - Password: el que generaste con htpasswd

2. **Odoo**: https://tudominio.com
   - Primera vez: crea una base de datos
   - Email master password: el que configuraste en `config/odoo.conf`

## Gestión de Módulos OCA

### Agregar módulos personalizados

```bash
# Clonar módulos OCA en la carpeta addons
cd addons

# Ejemplo: módulos de contabilidad
git clone https://github.com/OCA/account-financial-tools.git --branch 17.0 --depth 1

# Reiniciar Odoo para detectar nuevos módulos
docker compose restart odoo
```

### Actualizar lista de módulos

1. Accede a Odoo: https://tudominio.com
2. Activa modo desarrollador: Configuración > Activar modo desarrollador
3. Apps > Actualizar lista de aplicaciones

## Comandos Útiles

### Ver logs

```bash
# Logs de Odoo
docker logs -f odoo_app

# Logs de PostgreSQL
docker logs -f odoo_db

# Logs de Traefik
docker logs -f traefik
```

### Reiniciar servicios

```bash
# Reiniciar todo
docker compose restart

# Reiniciar solo Odoo
docker compose restart odoo
```

### Backups

```bash
# Backup de base de datos
docker exec odoo_db pg_dump -U odoo odoo > backup_$(date +%Y%m%d).sql

# Backup de volúmenes
docker run --rm -v odoo-web-data:/data -v $(pwd):/backup ubuntu tar czf /backup/odoo-data-$(date +%Y%m%d).tar.gz /data
```

### Restaurar backup

```bash
# Restaurar base de datos
docker exec -i odoo_db psql -U odoo odoo < backup_20250127.sql
```

## Troubleshooting

### SSL no funciona

1. Verifica que el puerto 80 y 443 estén abiertos
2. Revisa logs de Traefik: `docker logs traefik`
3. Verifica que el DNS apunte correctamente: `dig tudominio.com`

### Odoo no carga

1. Verifica logs: `docker logs odoo_app`
2. Verifica que PostgreSQL esté funcionando: `docker logs odoo_db`
3. Verifica conectividad: `docker exec odoo_app ping db`

### Error de permisos en acme.json

```bash
chmod 600 traefik/acme.json
```

### Módulos OCA no aparecen

1. Verifica que estén en la carpeta `addons/`
2. Reinicia Odoo: `docker compose restart odoo`
3. Actualiza lista de aplicaciones en Odoo

## Configuración de Producción

### Optimizar workers de Odoo

En `config/odoo.conf`, descomenta y ajusta:

```ini
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
```

### Deshabilitar Dashboard de Traefik

En `docker-compose.traefik.yml`, comenta la línea del puerto 8080:

```yaml
ports:
  - "80:80"
  - "443:443"
  # - "8080:8080"  # Comentar en producción
```

### Cambiar admin_passwd

En `config/odoo.conf`:

```ini
admin_passwd = tu_password_master_muy_seguro
```

## Actualizaciones

### Actualizar Odoo

```bash
# Cambiar versión en .env
ODOO_VERSION=18.0

# Recrear contenedor
docker compose up -d --force-recreate odoo
```

### Actualizar Traefik

```bash
docker compose -f docker-compose.traefik.yml pull
docker compose -f docker-compose.traefik.yml up -d
```

## Seguridad Adicional

### Limitar acceso a base de datos

En `config/odoo.conf`:

```ini
dbfilter = ^%d$
list_db = False
```

### Rate limiting

Los middlewares en `traefik/dynamic/middlewares.yml` ya incluyen rate limiting básico.

## Soporte

- Documentación oficial Odoo: https://www.odoo.com/documentation
- Documentación Traefik: https://doc.traefik.io/traefik/
- Módulos OCA: https://github.com/OCA

## Licencia

Este proyecto usa Odoo Community Edition bajo licencia LGPL-3.0.
