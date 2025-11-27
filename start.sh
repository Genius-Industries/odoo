#!/bin/bash

# Script de inicio para Odoo con Traefik
# Autor: Deployment Multi-departamental

set -e

echo "========================================="
echo "  Odoo + Traefik Deployment"
echo "========================================="
echo ""

# Verificar que existe .env
if [ ! -f .env ]; then
    echo "❌ Error: No se encontró el archivo .env"
    echo "📝 Copia .env.example a .env y configura tus variables:"
    echo "   cp .env.example .env"
    echo "   nano .env"
    exit 1
fi

# Verificar permisos de acme.json
if [ ! -f traefik/acme.json ]; then
    echo "📁 Creando traefik/acme.json..."
    touch traefik/acme.json
fi

echo "🔒 Configurando permisos de acme.json..."
chmod 600 traefik/acme.json

# Crear red de Traefik si no existe
if ! docker network inspect traefik-network >/dev/null 2>&1; then
    echo "🌐 Creando red traefik-network..."
    docker network create traefik-network
else
    echo "✅ Red traefik-network ya existe"
fi

# Cargar variables de entorno
source .env

echo ""
echo "📋 Configuración:"
echo "   Dominio: $DOMAIN"
echo "   Versión Odoo: $ODOO_VERSION"
echo "   Email SSL: $ACME_EMAIL"
echo ""

# Preguntar qué iniciar
echo "¿Qué deseas iniciar?"
echo "1) Solo Traefik"
echo "2) Solo Odoo (requiere Traefik corriendo)"
echo "3) Todo (Traefik + Odoo)"
echo "4) Detener todo"
echo ""
read -p "Selecciona una opción [1-4]: " option

case $option in
    1)
        echo "🚀 Iniciando Traefik..."
        docker compose -f docker-compose.traefik.yml up -d
        echo "✅ Traefik iniciado"
        echo "📊 Dashboard: https://traefik.$DOMAIN"
        ;;
    2)
        echo "🚀 Iniciando Odoo..."
        docker compose up -d
        echo "✅ Odoo iniciado"
        echo "🌐 URL: https://$DOMAIN"
        ;;
    3)
        echo "🚀 Iniciando Traefik..."
        docker compose -f docker-compose.traefik.yml up -d
        echo "⏳ Esperando 5 segundos..."
        sleep 5
        echo "🚀 Iniciando Odoo..."
        docker compose up -d
        echo ""
        echo "✅ Todos los servicios iniciados"
        echo "📊 Dashboard Traefik: https://traefik.$DOMAIN"
        echo "🌐 Odoo: https://$DOMAIN"
        ;;
    4)
        echo "🛑 Deteniendo servicios..."
        docker compose down
        docker compose -f docker-compose.traefik.yml down
        echo "✅ Servicios detenidos"
        ;;
    *)
        echo "❌ Opción inválida"
        exit 1
        ;;
esac

echo ""
echo "📝 Ver logs:"
echo "   docker logs -f traefik"
echo "   docker logs -f odoo_app"
echo "   docker logs -f odoo_db"
echo ""
echo "✅ Deployment completado"
