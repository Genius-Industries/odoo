# Guía de Deployment - Odoo + Traefik

## Arquitectura del Sistema

```
Internet
    │
    ├─── HTTP (80)  ──────┐
    │                     │
    └─── HTTPS (443) ─────┤
                          │
                          ▼
                    ┌──────────┐
                    │ TRAEFIK  │ (Reverse Proxy + SSL)
                    │  v3.6.2  │
                    └─────┬────┘
                          │
            ┌─────────────┼─────────────┐
            │             │             │
            ▼             ▼             ▼
    odoo.domain.com  traefik.domain.com  (dashboard)
            │
            ▼
      ┌─────────┐
      │  ODOO   │ (ERP System)
      │  19.0   │
      └────┬────┘
           │
           ▼
    ┌────────────┐
    │ PostgreSQL │ (Database)
    │    15      │
    └────────────┘
```

## Comparación: Configuración Anterior vs. Nueva

| Aspecto | ❌ Configuración Anterior | ✅ Nueva Configuración |
|---------|---------------------------|------------------------|
| **Archivos** | 2 archivos separados | 1 archivo unificado |
| **Redes** | Incompatibles (traefik-public vs traefik-network) | Una sola red: `traefik-public` |
| **Traefik Config** | Archivos externos faltantes | Todo inline en docker-compose |
| **Secrets** | Variables en .env | Docker secrets + .env |
| **Puerto Odoo** | No especificado | Explícitamente en label |
| **Health Checks** | No incluidos | PostgreSQL con healthcheck |
| **SSL Config** | Faltaban archivos | HTTP Challenge inline |
| **Funcional** | ❌ No funcionaría | ✅ Listo para producción |

## Cambios Principales Implementados

### 1. Unificación de Configuración

**Antes**: `docker-compose.yml` + `docker-compose.traefik.yml` (separados e incompatibles)

**Ahora**: Un solo `docker-compose.yml` con todo integrado

### 2. Configuración Traefik Inline

**Antes**: Requería archivos externos:
```yaml
volumes:
  - ./traefik/traefik.yml:/traefik.yml  # ❌ No existía
  - ./traefik/dynamic:/dynamic          # ❌ No existía
```

**Ahora**: Todo configurado via `command:` flags:
```yaml
command:
  - "--api.dashboard=true"
  - "--entrypoints.web.address=:80"
  - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"
```

### 3. Red Docker Unificada

**Antes**:
```yaml
# docker-compose.yml
networks:
  traefik-public:    # ❌ Red diferente
    external: true

# docker-compose.traefik.yml
networks:
  traefik-network:   # ❌ Red diferente
    external: true
```

**Ahora**:
```yaml
networks:
  traefik-public:    # ✅ Misma red para todos
    name: traefik-public
    driver: bridge
```

### 4. Gestión de Secrets

**Adaptado de configuración oficial de Odoo**:

```yaml
secrets:
  postgresql_password:
    file: odoo_pg_pass    # Archivo con password

# Usado en servicios:
environment:
  - POSTGRES_PASSWORD_FILE=/run/secrets/postgresql_password
```

### 5. Configuración Completa de Odoo con Traefik

**Labels agregados**:

```yaml
labels:
  # Router HTTPS
  - "traefik.http.routers.odoo.rule=Host(`odoo.${DOMAIN}`)"
  - "traefik.http.routers.odoo.tls.certresolver=letsencrypt"

  # Puerto del servicio
  - "traefik.http.services.odoo.loadbalancer.server.port=8069"

  # Headers para compatibilidad
  - "traefik.http.middlewares.odoo-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
```

## Instrucciones de Deployment en VPS

### Paso 1: Preparar DNS

Configura los siguientes registros A en tu proveedor DNS:

```
odoo.geniusindustries.org     →  IP_DE_TU_VPS
traefik.geniusindustries.org  →  IP_DE_TU_VPS
```

Verificar DNS:
```bash
nslookup odoo.geniusindustries.org
nslookup traefik.geniusindustries.org
```

### Paso 2: Preparar VPS

```bash
# Instalar Docker (si no está instalado)
curl -fsSL https://get.docker.com | sh

# Agregar usuario a grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Verificar instalación
docker --version
docker compose version
```

### Paso 3: Clonar/Subir Proyecto

```bash
# Opción 1: Git
cd /home/tu-usuario
git clone <tu-repositorio> odoo
cd odoo

# Opción 2: SCP (desde tu máquina local)
scp -r /ruta/local/odoo usuario@IP_VPS:/home/usuario/
```

### Paso 4: Configurar Variables

```bash
cd /home/usuario/odoo
nano .env
```

Verifica que esté configurado:
```env
DOMAIN=geniusindustries.org
ACME_EMAIL=admin@geniusindustries.org
ODOO_VERSION=19.0
```

### Paso 5: Ejecutar Setup

```bash
chmod +x setup.sh
./setup.sh
```

El script preguntará si quieres iniciar los servicios. Responde `y`.

### Paso 6: Verificar Deployment

```bash
# Ver containers corriendo
docker compose ps

# Ver logs en tiempo real
docker compose logs -f

# Verificar SSL (después de 1-2 minutos)
curl -I https://odoo.geniusindustries.org
```

## Verificación de Funcionamiento

### ✅ Checklist de Validación

- [ ] DNS apunta correctamente a IP del VPS
- [ ] Puertos 80 y 443 abiertos en firewall
- [ ] Containers corriendo: `docker compose ps`
- [ ] PostgreSQL healthy: `docker compose ps db` (muestra "healthy")
- [ ] Traefik obtuvo certificado SSL: `docker compose logs traefik | grep acme`
- [ ] Odoo accesible: `https://odoo.geniusindustries.org`
- [ ] Dashboard Traefik accesible: `https://traefik.geniusindustries.org`
- [ ] Redirección HTTP → HTTPS funciona

### Comandos de Diagnóstico

```bash
# Estado de servicios
docker compose ps

# Logs de certificado SSL
docker compose logs traefik | grep -i acme

# Logs de conexión Odoo-PostgreSQL
docker compose logs odoo | grep -i database

# Test de conectividad interna
docker compose exec odoo ping -c 3 db
docker compose exec odoo curl -I http://localhost:8069

# Verificar red Docker
docker network ls | grep traefik
docker network inspect traefik-public
```

## Mantenimiento Post-Deployment

### Acceso Inicial a Odoo

1. Abre: `https://odoo.geniusindustries.org`
2. Crea la primera base de datos:
   - **Master Password**: (definido en `config/odoo.conf`)
   - **Database Name**: `production`
   - **Email**: tu email
   - **Password**: contraseña de administrador
   - **Language**: Spanish
   - **Country**: Colombia

### Cambiar Password de Admin

```bash
# Editar config
nano config/odoo.conf

# Cambiar línea:
admin_passwd = TU_PASSWORD_SEGURO

# Reiniciar Odoo
docker compose restart odoo
```

### Monitoreo

```bash
# Logs en tiempo real
docker compose logs -f

# Solo errores
docker compose logs --tail=100 | grep -i error

# Uso de recursos
docker stats
```

### Backups Automáticos

Agrega a crontab (`crontab -e`):

```bash
# Backup diario a las 2 AM
0 2 * * * cd /home/usuario/odoo && docker compose exec -T db pg_dumpall -U odoo > /backups/odoo_$(date +\%Y\%m\%d).sql
```

## Problemas Resueltos

### ✅ Red Docker Incompatible
**Problema**: Traefik y Odoo en redes diferentes
**Solución**: Una sola red `traefik-public` para todos los servicios

### ✅ Archivos Traefik Faltantes
**Problema**: `./traefik/traefik.yml` no existía
**Solución**: Configuración inline via `command:` flags

### ✅ Puerto Odoo No Especificado
**Problema**: Traefik no sabía conectarse a puerto 8069
**Solución**: Label `traefik.http.services.odoo.loadbalancer.server.port=8069`

### ✅ Certificado SSL No Se Genera
**Problema**: acme.json requiere permisos 600
**Solución**: Volumen named `traefik-acme` con permisos correctos

### ✅ Headers HTTP Incorrectos
**Problema**: Odoo no detectaba HTTPS detrás de proxy
**Solución**: Middleware con headers `X-Forwarded-Proto` y `X-Forwarded-Host`

## Próximos Pasos Recomendados

1. **Seguridad**:
   - Cambiar todos los passwords por defecto
   - Configurar firewall (ufw)
   - Deshabilitar dashboard inseguro en puerto 8080

2. **Optimización**:
   - Agregar workers de Odoo en `config/odoo.conf`
   - Configurar límites de recursos en docker-compose
   - Implementar backups automáticos

3. **Módulos**:
   - Instalar módulos OCA en `addons/`
   - Configurar módulos personalizados

4. **Monitoreo**:
   - Configurar alertas con Traefik
   - Integrar con sistema de logging externo

## Soporte Técnico

**Logs importantes**:
```bash
# Ver todo
docker compose logs -f

# Solo Traefik
docker compose logs -f traefik

# Solo Odoo
docker compose logs -f odoo

# Solo PostgreSQL
docker compose logs -f db
```

**Reiniciar servicios**:
```bash
# Reiniciar todo
docker compose restart

# Reiniciar solo Odoo
docker compose restart odoo
```

**Resetear completamente**:
```bash
# ⚠️ CUIDADO: Borra todos los datos
docker compose down -v
rm -rf config/odoo.conf
./setup.sh
```

---

**Estado**: ✅ Configuración lista para producción
**Última actualización**: 2024-11-30
**Versiones**: Odoo 19.0 | Traefik 3.6.2 | PostgreSQL 15
