#!/bin/bash

# Script para configurar .env correctamente
# Autor: Studio-Operations Team

echo "========================================="
echo "  Setup de Archivo .env para Odoo"
echo "========================================="
echo ""

# Verificar si .env ya existe
if [ -f .env ]; then
    echo "⚠️  El archivo .env ya existe."
    read -p "¿Deseas sobrescribirlo? (s/N): " respuesta
    if [[ ! $respuesta =~ ^[Ss]$ ]]; then
        echo "❌ Operación cancelada."
        exit 0
    fi
fi

# Copiar desde .env.example
if [ ! -f .env.example ]; then
    echo "❌ Error: .env.example no encontrado"
    exit 1
fi

echo "📋 Configurando variables de entorno..."
echo ""

# Solicitar información al usuario
read -p "Dominio principal (ej: geniusindustries.org): " DOMAIN
read -p "Email para SSL/Let's Encrypt: " ACME_EMAIL
read -p "Password de PostgreSQL: " POSTGRES_PASSWORD
read -p "Versión de Odoo (17.0, 18.0, 19.0) [19.0]: " ODOO_VERSION
ODOO_VERSION=${ODOO_VERSION:-19.0}

echo ""
echo "🔐 Generando autenticación para Dashboard Traefik..."
read -p "Usuario dashboard Traefik [admin]: " TRAEFIK_USER
TRAEFIK_USER=${TRAEFIK_USER:-admin}
read -sp "Password dashboard Traefik: " TRAEFIK_PASS
echo ""

# Verificar si htpasswd está disponible
if command -v htpasswd &> /dev/null; then
    TRAEFIK_AUTH=$(htpasswd -nb "$TRAEFIK_USER" "$TRAEFIK_PASS" | sed -e s/\\$/\\$\\$/g)
else
    echo "⚠️  htpasswd no disponible. Usando hash de ejemplo (CAMBIAR LUEGO)."
    TRAEFIK_AUTH="admin:\$\$apr1\$\$xyz\$\$abc123"
fi

# Crear archivo .env
cat > .env << EOF
# ===================================
# CONFIGURACIÓN ODOO
# ===================================

# Versión de Odoo (17.0, 18.0, 19.0)
ODOO_VERSION=$ODOO_VERSION

# Dominio principal (SIN www, SIN http://)
DOMAIN=$DOMAIN

# ===================================
# BASE DE DATOS POSTGRESQL
# ===================================

POSTGRES_DB=odoo
POSTGRES_USER=odoo
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Host de la base de datos (no cambiar si usas docker-compose)
DB_HOST=db

# ===================================
# TRAEFIK & SSL
# ===================================

# Email para Let's Encrypt (REQUERIDO para SSL)
ACME_EMAIL=$ACME_EMAIL

# Autenticación del Dashboard Traefik
TRAEFIK_DASHBOARD_AUTH=$TRAEFIK_AUTH

# ===================================
# CONFIGURACIÓN ADICIONAL
# ===================================

# Zona horaria
TZ=America/Bogota
EOF

echo ""
echo "✅ Archivo .env creado exitosamente"
echo ""
echo "📋 Configuración guardada:"
echo "   Dominio: $DOMAIN"
echo "   Email SSL: $ACME_EMAIL"
echo "   Versión Odoo: $ODOO_VERSION"
echo ""
echo "🔒 Configurando permisos..."
chmod 600 .env
chmod 600 traefik/acme.json 2>/dev/null || touch traefik/acme.json && chmod 600 traefik/acme.json

echo ""
echo "✅ Setup completado!"
echo ""
echo "📝 URLs que estarán disponibles:"
echo "   Odoo:              https://$DOMAIN"
echo "   Traefik Dashboard: https://traefik.$DOMAIN"
echo ""
echo "🚀 Siguiente paso:"
echo "   sudo ./start.sh"
echo ""
