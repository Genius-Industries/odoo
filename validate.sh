#!/bin/bash

# Script de validación de configuración
# Verifica que todos los archivos y configuraciones estén listos

echo "========================================="
echo "  Validación de Configuración Odoo"
echo "========================================="
echo ""

ERRORS=0
WARNINGS=0

# Función para reportar errores
error() {
    echo "❌ ERROR: $1"
    ((ERRORS++))
}

# Función para reportar warnings
warning() {
    echo "⚠️  WARNING: $1"
    ((WARNINGS++))
}

# Función para reportar OK
ok() {
    echo "✅ $1"
}

# Verificar archivos necesarios
echo "📁 Verificando archivos necesarios..."
[ -f docker-compose.yml ] && ok "docker-compose.yml existe" || error "docker-compose.yml no encontrado"
[ -f docker-compose.traefik.yml ] && ok "docker-compose.traefik.yml existe" || error "docker-compose.traefik.yml no encontrado"
[ -f .env.example ] && ok ".env.example existe" || error ".env.example no encontrado"
[ -f traefik/traefik.yml ] && ok "traefik/traefik.yml existe" || error "traefik/traefik.yml no encontrado"
[ -f traefik/acme.json ] && ok "traefik/acme.json existe" || error "traefik/acme.json no encontrado"
[ -f config/odoo.conf ] && ok "config/odoo.conf existe" || error "config/odoo.conf no encontrado"

echo ""
echo "🔐 Verificando permisos..."
if [ -f traefik/acme.json ]; then
    PERMS=$(stat -c %a traefik/acme.json)
    if [ "$PERMS" = "600" ]; then
        ok "traefik/acme.json tiene permisos correctos (600)"
    else
        error "traefik/acme.json tiene permisos $PERMS (debe ser 600)"
        echo "   Ejecuta: chmod 600 traefik/acme.json"
    fi
fi

if [ -f start.sh ]; then
    [ -x start.sh ] && ok "start.sh es ejecutable" || warning "start.sh no es ejecutable (chmod +x start.sh)"
fi

echo ""
echo "📋 Verificando archivo .env..."
if [ -f .env ]; then
    ok ".env existe"

    # Verificar variables críticas
    source .env 2>/dev/null

    [ -n "$DOMAIN" ] && ok "DOMAIN configurado: $DOMAIN" || error "DOMAIN no configurado"
    [ -n "$POSTGRES_PASSWORD" ] && ok "POSTGRES_PASSWORD configurado" || error "POSTGRES_PASSWORD no configurado"
    [ -n "$ACME_EMAIL" ] && ok "ACME_EMAIL configurado: $ACME_EMAIL" || error "ACME_EMAIL no configurado"
    [ -n "$ODOO_VERSION" ] && ok "ODOO_VERSION configurado: $ODOO_VERSION" || warning "ODOO_VERSION no configurado (usará default)"

    # Verificar si usa password por defecto
    if [ "$POSTGRES_PASSWORD" = "tu_password_seguro_aqui" ]; then
        warning "POSTGRES_PASSWORD usa el valor por defecto. Cámbialo por seguridad."
    fi

else
    error ".env no encontrado"
    echo "   Ejecuta: cp .env.example .env"
    echo "   Luego edita .env con tus valores"
fi

echo ""
echo "🐳 Verificando Docker..."
if command -v docker &> /dev/null; then
    ok "Docker está instalado"

    if docker info &> /dev/null; then
        ok "Docker daemon está corriendo"
    else
        error "Docker daemon no está corriendo"
        echo "   Ejecuta: sudo systemctl start docker"
    fi

    # Verificar docker compose
    if docker compose version &> /dev/null; then
        ok "Docker Compose está disponible"
    else
        error "Docker Compose no está disponible"
    fi
else
    error "Docker no está instalado"
fi

echo ""
echo "🌐 Verificando red Docker..."
if docker network inspect traefik-network &> /dev/null; then
    ok "Red traefik-network existe"
else
    warning "Red traefik-network no existe (se creará automáticamente)"
    echo "   O ejecuta: docker network create traefik-network"
fi

echo ""
echo "📂 Verificando estructura de carpetas..."
[ -d addons ] && ok "Carpeta addons/ existe" || error "Carpeta addons/ no existe"
[ -d config ] && ok "Carpeta config/ existe" || error "Carpeta config/ no existe"
[ -d traefik ] && ok "Carpeta traefik/ existe" || error "Carpeta traefik/ no existe"
[ -d traefik/dynamic ] && ok "Carpeta traefik/dynamic/ existe" || error "Carpeta traefik/dynamic/ no existe"

echo ""
echo "========================================="
echo "  Resumen de Validación"
echo "========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ ¡Configuración perfecta! Todo listo para deployment."
    echo ""
    echo "Siguiente paso:"
    echo "   make start"
    echo "   o"
    echo "   ./start.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "✅ Configuración válida con $WARNINGS advertencia(s)."
    echo "   Puedes continuar, pero revisa las advertencias."
    exit 0
else
    echo "❌ Se encontraron $ERRORS error(es) y $WARNINGS advertencia(s)."
    echo "   Corrige los errores antes de continuar."
    exit 1
fi
