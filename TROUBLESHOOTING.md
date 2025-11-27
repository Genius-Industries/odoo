# Troubleshooting Guide - Odoo con Traefik

Guía de resolución de problemas comunes durante el deployment.

## Error: "client version 1.24 is too old"

### Síntoma
```
ERR Provider error error="Error response from daemon: client version 1.24 is too old.
Minimum supported API version is 1.44, please upgrade your client to a newer version"
```

### Causa
- Incompatibilidad entre la versión de Traefik y el Docker Engine moderno
- Traefik v3.2 inicial tenía issues con Docker API 1.44+

### Solución
**Opción 1: Usar Traefik v3.6.2+ (Recomendado)**
```yaml
# docker-compose.traefik.yml
services:
  traefik:
    image: traefik:v3.6.2  # última versión estable
```

**Opción 2: Downgrade Docker (No recomendado)**
Si estás en desarrollo local, podrías usar una versión anterior de Docker, pero NO se recomienda para producción.

### Verificación
```bash
# Después de actualizar
sudo docker compose -f docker-compose.traefik.yml down
sudo docker compose -f docker-compose.traefik.yml up -d
sudo docker logs traefik

# Deberías ver:
# ✅ Configuration loaded from file: /traefik.yml
# ✅ Starting provider *docker.Provider
```

---

## Warning: "version is obsolete"

### Síntoma
```
WARN[0000] the attribute `version` is obsolete, it will be ignored
```

### Causa
Docker Compose v2 ya no requiere el atributo `version`

### Solución
Eliminar la línea `version: '3.8'` de los archivos docker-compose:

```yaml
# Antes
version: '3.8'
services:
  ...

# Después
services:
  ...
```

---

## Error: "network has incorrect label"

### Síntoma
```
network traefik-network was found but has incorrect label
com.docker.compose.network set to "" (expected: "traefik-network")
```

### Causa
La red fue creada manualmente y luego Docker Compose intenta gestionarla

### Solución
Marcar la red como `external: true`:

```yaml
networks:
  traefik-network:
    name: traefik-network
    external: true
```

Luego recrear la red:
```bash
sudo docker network rm traefik-network
sudo docker network create traefik-network
```

O usar el script `start.sh` que lo hace automáticamente.

---

## SSL Certificates no generan

### Síntoma
- No se generan certificados SSL
- Error: "unable to get acme client: too many registrations"

### Causa
1. Let's Encrypt tiene rate limit (5 certificados/semana por dominio)
2. Permisos incorrectos en acme.json
3. Puertos 80/443 bloqueados

### Solución

**1. Verificar permisos acme.json:**
```bash
chmod 600 traefik/acme.json
```

**2. Verificar puertos abiertos:**
```bash
sudo netstat -tlnp | grep -E ':(80|443)'
```

**3. Si excediste rate limit:**
Usa staging de Let's Encrypt temporalmente:

```yaml
# traefik/traefik.yml
certificatesResolvers:
  letsencrypt:
    acme:
      caServer: https://acme-staging-v02.api.letsencrypt.org/directory
      email: ${ACME_EMAIL}
      storage: acme.json
```

**4. DNS Challenge (alternativa):**
Si no puedes usar puertos 80/443, usa DNS challenge con Cloudflare:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

---

## Odoo no carga / 502 Bad Gateway

### Síntoma
Al acceder a tu dominio aparece error 502 o página no carga

### Diagnóstico
```bash
# 1. Verificar que Odoo esté corriendo
sudo docker ps | grep odoo

# 2. Ver logs de Odoo
sudo docker logs odoo_app

# 3. Ver logs de Traefik
sudo docker logs traefik

# 4. Verificar conectividad interna
sudo docker exec traefik ping odoo_app
```

### Causas Comunes

**1. PostgreSQL no está listo:**
```bash
# Ver logs de DB
sudo docker logs odoo_db

# Verificar healthcheck
sudo docker inspect odoo_db | grep -A 10 Health
```

**Solución:** Esperar a que PostgreSQL esté healthy o reiniciar:
```bash
sudo docker compose restart db
```

**2. Puerto incorrecto en labels:**
Verificar en docker-compose.yml:
```yaml
- "traefik.http.services.odoo.loadbalancer.server.port=8069"
```

**3. Red incorrecta:**
Verificar que Odoo esté en `traefik-network`:
```bash
sudo docker network inspect traefik-network
```

---

## Error: "permission denied while connecting to Docker API"

### Síntoma
```
permission denied while trying to connect to the docker API
```

### Causa
Usuario no tiene permisos para usar Docker

### Solución

**Opción 1: Agregar usuario a grupo docker (Recomendado)**
```bash
sudo usermod -aG docker $USER
newgrp docker

# Verificar
docker ps
```

**Opción 2: Usar sudo**
```bash
sudo docker compose up -d
```

---

## Variables de entorno no cargan

### Síntoma
Errores como "POSTGRES_PASSWORD is not set"

### Solución

**1. Verificar que .env existe:**
```bash
ls -la .env
```

**2. Verificar formato correcto:**
```bash
# .env NO debe tener espacios alrededor del =
DOMAIN=tudominio.com        # ✅ Correcto
DOMAIN = tudominio.com      # ❌ Incorrecto
```

**3. Recargar variables:**
```bash
source .env
docker compose config  # Verifica variables expandidas
```

---

## Módulos OCA no aparecen

### Síntoma
Módulos en carpeta `addons/` no aparecen en Odoo

### Solución

**1. Verificar montaje del volumen:**
```bash
sudo docker exec odoo_app ls -la /mnt/extra-addons
```

**2. Verificar permisos:**
```bash
sudo chown -R 101:101 addons/
```

**3. Reiniciar Odoo:**
```bash
sudo docker compose restart odoo
```

**4. Actualizar lista en Odoo:**
- Ir a Apps
- Activar modo desarrollador (Configuración > Activar modo desarrollador)
- Actualizar lista de aplicaciones

---

## Dashboard Traefik no accesible

### Síntoma
No puedes acceder a https://traefik.tudominio.com

### Solución

**1. Verificar que dashboard esté habilitado:**
```yaml
# traefik/traefik.yml
api:
  dashboard: true
```

**2. Verificar puerto 8080 (desarrollo):**
```bash
curl http://localhost:8080/dashboard/
```

**3. Verificar autenticación:**
Genera el hash correcto:
```bash
echo $(htpasswd -nb admin tupassword) | sed -e s/\\$/\\$\\$/g
```

Agregar a .env:
```
TRAEFIK_DASHBOARD_AUTH=admin:$$apr1$$...
```

---

## Backup y Restauración

### Backup manual

**Base de datos:**
```bash
sudo docker exec odoo_db pg_dump -U odoo odoo > backup_$(date +%Y%m%d).sql
```

**Volúmenes:**
```bash
sudo docker run --rm \
  -v odoo-web-data:/data \
  -v $(pwd)/backups:/backup \
  ubuntu tar czf /backup/odoo-data-$(date +%Y%m%d).tar.gz /data
```

### Restauración

**Base de datos:**
```bash
sudo docker exec -i odoo_db psql -U odoo odoo < backup_20251127.sql
```

---

## Comandos Útiles de Diagnóstico

```bash
# Estado de todos los contenedores
sudo docker compose ps
sudo docker compose -f docker-compose.traefik.yml ps

# Logs en tiempo real
sudo docker logs -f traefik
sudo docker logs -f odoo_app
sudo docker logs -f odoo_db

# Inspeccionar redes
sudo docker network ls
sudo docker network inspect traefik-network

# Uso de recursos
sudo docker stats

# Entrar a un contenedor
sudo docker exec -it traefik sh
sudo docker exec -it odoo_app bash
sudo docker exec -it odoo_db psql -U odoo

# Limpiar todo (¡CUIDADO! Elimina volúmenes)
sudo docker compose down -v
sudo docker compose -f docker-compose.traefik.yml down -v
```

---

## Soporte Adicional

Si ninguna de estas soluciones funciona:

1. Revisa los logs completos:
   ```bash
   sudo docker logs traefik > traefik-full.log
   sudo docker logs odoo_app > odoo-full.log
   ```

2. Verifica la configuración:
   ```bash
   sudo docker compose config
   ```

3. Consulta documentación oficial:
   - [Traefik Docs](https://doc.traefik.io/traefik/)
   - [Odoo Docs](https://www.odoo.com/documentation)

4. GitHub Issues del proyecto
