#!/bin/bash

###############################################################################
# Script de inicialización para Odoo con Traefik
# Configuración automática del entorno de deployment
###############################################################################

set -e

echo "========================================"
echo "  Odoo + Traefik Setup Script"
echo "========================================"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${NC}ℹ${NC} $1"
}

# 1. Verificar que existe el archivo .env
if [ ! -f .env ]; then
    print_error "Archivo .env no encontrado"
    print_info "Creando archivo .env desde plantilla..."

    cat > .env << 'EOF'
# ===================================
# CONFIGURACIÓN ODOO
# ===================================

# Versión de Odoo (17.0, 18.0, 19.0)
ODOO_VERSION=19.0

# Dominio principal (CAMBIAR POR TU DOMINIO)
DOMAIN=geniusindustries.org

# ===================================
# TRAEFIK & SSL
# ===================================

# Email para Let's Encrypt (CAMBIAR)
ACME_EMAIL=admin@geniusindustries.org

# Autenticación del Dashboard Traefik
# Generar con: echo $(htpasswd -nb admin tu_password) | sed -e s/\\$/\\$\\$/g
# Usuario: admin, Password: admin (CAMBIAR EN PRODUCCIÓN)
TRAEFIK_DASHBOARD_AUTH=admin:$$apr1$$8g1nh0jm$$RGQwWvGMzjP3PsLd7qVe21

# ===================================
# CONFIGURACIÓN ADICIONAL
# ===================================

# Zona horaria
TZ=America/Bogota
EOF
    print_success "Archivo .env creado. Por favor, edítalo con tus valores antes de continuar."
    exit 0
fi

print_success "Archivo .env encontrado"

# 2. Verificar que existe odoo_pg_pass
if [ ! -f odoo_pg_pass ]; then
    print_warning "Archivo odoo_pg_pass no encontrado"
    print_info "Generando password aleatorio..."
    openssl rand -base64 32 > odoo_pg_pass
    print_success "Password de PostgreSQL generado en odoo_pg_pass"
fi

# 3. Crear directorios necesarios
print_info "Creando directorios necesarios..."
mkdir -p config
mkdir -p addons
print_success "Directorios creados"

# 4. Verificar permisos
print_info "Configurando permisos..."
chmod 600 odoo_pg_pass
print_success "Permisos configurados"

# 5. Detener containers existentes (si existen)
print_info "Deteniendo containers existentes..."
docker-compose down 2>/dev/null || true
print_success "Containers detenidos"

# 6. Limpiar volúmenes huérfanos
print_info "Limpiando volúmenes huérfanos..."
docker volume prune -f > /dev/null 2>&1 || true
print_success "Volúmenes limpiados"

# 7. Validar docker-compose.yml
print_info "Validando configuración de Docker Compose..."
if docker-compose config > /dev/null 2>&1; then
    print_success "Configuración válida"
else
    print_error "Error en docker-compose.yml"
    docker-compose config
    exit 1
fi

# 8. Información de deployment
echo ""
echo "========================================"
echo "  Configuración lista para deployment"
echo "========================================"
echo ""
print_info "Dominio configurado: $(grep DOMAIN= .env | cut -d'=' -f2)"
print_info "URLs que se crearán:"
echo "   - https://odoo.$(grep DOMAIN= .env | cut -d'=' -f2) (Odoo)"
echo "   - https://traefik.$(grep DOMAIN= .env | cut -d'=' -f2) (Traefik Dashboard)"
echo ""

# 9. Preguntar si desea iniciar
read -p "¿Deseas iniciar los servicios ahora? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Iniciando servicios..."
    docker-compose up -d

    echo ""
    print_success "Servicios iniciados correctamente"
    echo ""
    print_info "Verificando estado de los servicios..."
    sleep 3
    docker-compose ps

    echo ""
    print_warning "IMPORTANTE: Asegúrate de que tu dominio apunte a la IP de este servidor"
    print_info "Puedes ver los logs con: docker-compose logs -f"
    print_info "Dashboard de Traefik: http://$(grep DOMAIN= .env | cut -d'=' -f2):8080"
else
    print_info "Para iniciar los servicios manualmente, ejecuta: docker-compose up -d"
fi

echo ""
print_success "Setup completado"
