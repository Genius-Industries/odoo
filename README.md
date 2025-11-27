# Odoo con Traefik - Deployment Production-Ready

Configuración completa de Odoo con Traefik como reverse proxy, SSL automático y soporte para módulos OCA.

## Características

- **Traefik v3.6.2**: Reverse proxy con SSL automático via Let's Encrypt
- **Odoo 17.0/18.0/19.0**: Selecciona la versión que necesites
- **PostgreSQL 15**: Base de datos robusta y optimizada
- **Módulos OCA**: Carpeta `addons/` lista para módulos personalizados
- **SSL automático**: Certificados HTTPS gratuitos y renovación automática
- **Docker Compose**: Orchestración simple y reproducible
- **Healthchecks**: Verificación de salud de servicios
- **Networking aislado**: Seguridad entre servicios

## Arquitectura

```
Internet
    ↓
Traefik (SSL/Reverse Proxy)
    ↓
Odoo (Port 8069/8072)
    ↓
PostgreSQL (Port 5432)
```

## Quick Start

### 1. Configuración inicial

```bash
# Clonar/usar este repositorio
cd /path/to/odoo

# Copiar y editar variables de entorno
cp .env.example .env
nano .env

# Configurar dominio, passwords, email SSL, etc.
```

### 2. Deployment

```bash
# Opción A: Usando Makefile (recomendado)
make init      # Inicializa configuración
make start     # Inicia todos los servicios

# Opción B: Usando script
./start.sh     # Menú interactivo

# Opción C: Manual
docker network create traefik-network
docker compose -f docker-compose.traefik.yml up -d
docker compose up -d
```

### 3. Acceso

- **Odoo**: https://tudominio.com
- **Traefik Dashboard**: https://traefik.tudominio.com

## Comandos Útiles

```bash
# Ver todos los comandos disponibles
make help

# Ver logs
make logs-odoo
make logs-traefik
make logs-db

# Backups
make backup-db
make backup-volumes

# Reiniciar
make restart

# Detener
make stop
```

## Módulos OCA

Agrega módulos personalizados en la carpeta `addons/`:

```bash
cd addons/
git clone https://github.com/OCA/web.git --branch 17.0 --depth 1
make restart
```

Luego actualiza la lista de aplicaciones en Odoo.

## Estructura del Proyecto

```
odoo/
├── docker-compose.yml              # Odoo + PostgreSQL
├── docker-compose.traefik.yml      # Traefik
├── .env                            # Variables de entorno
├── .env.example                    # Plantilla de configuración
├── Makefile                        # Comandos útiles
├── start.sh                        # Script de inicio
├── DEPLOYMENT.md                   # Guía completa de deployment
├── addons/                         # Módulos OCA
├── config/
│   └── odoo.conf                   # Configuración Odoo
└── traefik/
    ├── traefik.yml                 # Config Traefik
    ├── acme.json                   # Certificados SSL
    └── dynamic/
        └── middlewares.yml         # Seguridad

```

## Documentación

- 📖 **[DEPLOYMENT.md](./DEPLOYMENT.md)**: Guía completa de instalación y configuración
- 📋 **[CLAUDE.md](./CLAUDE.md)**: Reglas de desarrollo del proyecto

## Soporte

- [Documentación Odoo](https://www.odoo.com/documentation)
- [Documentación Traefik](https://doc.traefik.io/traefik/)
- [Módulos OCA](https://github.com/OCA)

## Licencia

Odoo Community Edition - LGPL-3.0

---

**Configuración creada por el equipo multi-departamental de desarrollo**
