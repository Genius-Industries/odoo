#!/bin/bash

# Script para reset completo del deployment
# Usar cuando cambias passwords o necesitas empezar desde cero
# ADVERTENCIA: Esto eliminará TODOS los datos de PostgreSQL y Odoo

set -e

echo "========================================="
echo "  RESET COMPLETO - Odoo Deployment"
echo "========================================="
echo ""
echo "⚠️  ADVERTENCIA: Esto eliminará:"
echo "   - Todos los datos de PostgreSQL"
echo "   - Todos los datos de Odoo"
echo "   - Certificados SSL generados"
echo "   - Redes Docker creadas"
echo ""
read -p "¿Estás seguro de continuar? (escribe SI): " confirmacion

if [ "$confirmacion" != "SI" ]; then
    echo "❌ Reset cancelado"
    exit 0
fi

echo ""
echo "🛑 Deteniendo servicios..."
sudo docker compose down 2>/dev/null || true
sudo docker compose -f docker-compose.traefik.yml down 2>/dev/null || true

echo ""
echo "🗑️  Eliminando volúmenes Docker..."
sudo docker volume rm odoo-db-data 2>/dev/null && echo "✅ odoo-db-data eliminado" || echo "⚠️  odoo-db-data no existía"
sudo docker volume rm odoo-web-data 2>/dev/null && echo "✅ odoo-web-data eliminado" || echo "⚠️  odoo-web-data no existía"

echo ""
echo "🔑 Limpiando certificados SSL..."
if [ -f traefik/acme.json ]; then
    sudo rm traefik/acme.json
    echo "✅ acme.json eliminado"
fi
sudo touch traefik/acme.json
sudo chmod 600 traefik/acme.json
echo "✅ acme.json recreado con permisos correctos"

echo ""
echo "🌐 Recreando red Docker..."
sudo docker network rm traefik-network 2>/dev/null && echo "✅ red traefik-network eliminada" || echo "⚠️  red no existía"
sudo docker network create traefik-network
echo "✅ red traefik-network creada"

echo ""
echo "🔍 Verificando archivo .env..."
if [ ! -f .env ]; then
    echo "❌ ERROR: Archivo .env no existe"
    echo "   Ejecuta primero: ./setup-env.sh"
    exit 1
fi

echo "✅ Archivo .env encontrado"
echo ""
echo "📋 Configuración actual:"
grep -E '(DOMAIN|ACME_EMAIL|ODOO_VERSION)=' .env | sed 's/^/   /'

echo ""
echo "✅ Reset completado exitosamente!"
echo ""
echo "🚀 Siguiente paso:"
echo "   sudo ./start.sh"
echo "   (Selecciona opción 3: Todo)"
echo ""
