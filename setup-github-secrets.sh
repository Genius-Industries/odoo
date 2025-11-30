#!/bin/bash

###############################################################################
# GitHub Secrets Setup Helper
# Configura automáticamente los secrets necesarios en GitHub
###############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

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

# Verificar GitHub CLI
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI no encontrado"
    echo ""
    print_info "Instala GitHub CLI desde: https://cli.github.com/"
    echo ""
    echo "Ubuntu/Debian:"
    echo "  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "  echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
    echo "  sudo apt update && sudo apt install gh"
    echo ""
    echo "macOS:"
    echo "  brew install gh"
    exit 1
fi

print_header "GitHub Secrets Setup"

# Verificar autenticación
print_info "Verificando autenticación con GitHub..."
if ! gh auth status &> /dev/null; then
    print_warning "No autenticado con GitHub"
    print_info "Iniciando proceso de autenticación..."
    gh auth login
fi
print_success "Autenticado con GitHub"

echo ""

# Obtener información del repositorio actual
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")

if [ -z "$REPO" ]; then
    print_warning "No se detectó repositorio automáticamente"
    read -p "Ingresa el repositorio (formato: usuario/repo): " REPO
fi

print_success "Repositorio: $REPO"
echo ""

# Verificar que estamos en el repo correcto
read -p "¿Es correcto el repositorio '$REPO'? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Proceso cancelado"
    exit 1
fi

echo ""
print_header "Configuración de Secrets"
echo ""

# DOMAIN
print_info "1/6 Configurando DOMAIN"
read -p "Ingresa el dominio (ej: geniusindustries.org): " DOMAIN

if [ -z "$DOMAIN" ]; then
    print_error "El dominio no puede estar vacío"
    exit 1
fi

gh secret set DOMAIN -b "$DOMAIN" -R "$REPO"
print_success "DOMAIN configurado"
echo ""

# ODOO_VERSION
print_info "2/6 Configurando ODOO_VERSION"
echo "Versiones disponibles: 17.0, 18.0, 19.0"
read -p "Ingresa la versión de Odoo (default: 19.0): " ODOO_VERSION
ODOO_VERSION=${ODOO_VERSION:-19.0}

gh secret set ODOO_VERSION -b "$ODOO_VERSION" -R "$REPO"
print_success "ODOO_VERSION configurado: $ODOO_VERSION"
echo ""

# ACME_EMAIL
print_info "3/6 Configurando ACME_EMAIL"
read -p "Ingresa email para Let's Encrypt (ej: admin@$DOMAIN): " ACME_EMAIL

if [ -z "$ACME_EMAIL" ]; then
    ACME_EMAIL="admin@$DOMAIN"
    print_warning "Usando email por defecto: $ACME_EMAIL"
fi

gh secret set ACME_EMAIL -b "$ACME_EMAIL" -R "$REPO"
print_success "ACME_EMAIL configurado"
echo ""

# POSTGRES_PASSWORD
print_info "4/6 Configurando POSTGRES_PASSWORD"
print_info "Generando password seguro..."

if command -v openssl &> /dev/null; then
    POSTGRES_PASSWORD=$(openssl rand -base64 32)
    print_success "Password generado con OpenSSL"
else
    POSTGRES_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*' | fold -w 32 | head -n 1)
    print_success "Password generado aleatoriamente"
fi

gh secret set POSTGRES_PASSWORD -b "$POSTGRES_PASSWORD" -R "$REPO"
print_success "POSTGRES_PASSWORD configurado"
echo ""

# TZ
print_info "5/6 Configurando TZ (Timezone)"
echo "Zonas horarias comunes:"
echo "  - America/Bogota"
echo "  - America/New_York"
echo "  - America/Chicago"
echo "  - America/Los_Angeles"
echo "  - Europe/Madrid"
echo "  - UTC"
read -p "Ingresa zona horaria (default: America/Bogota): " TZ
TZ=${TZ:-America/Bogota}

gh secret set TZ -b "$TZ" -R "$REPO"
print_success "TZ configurado: $TZ"
echo ""

# TRAEFIK_DASHBOARD_AUTH
print_info "6/6 Configurando TRAEFIK_DASHBOARD_AUTH"
echo ""
print_warning "Este secret requiere un hash de password en formato htpasswd"
echo ""
echo "Opciones para generar:"
echo "  1. Online: https://hostingcanada.org/htpasswd-generator/"
echo "     (Importante: reemplaza \$ por \$\$ en el resultado)"
echo ""
echo "  2. Con htpasswd (si está instalado):"
echo "     echo \$(htpasswd -nb admin password) | sed -e s/\\\\\$/\\\$\\\$/g"
echo ""

if command -v htpasswd &> /dev/null; then
    read -p "¿Quieres generar el hash automáticamente? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -s -p "Ingresa password para el dashboard de Traefik: " DASHBOARD_PASSWORD
        echo ""
        read -s -p "Confirma password: " DASHBOARD_PASSWORD_CONFIRM
        echo ""

        if [ "$DASHBOARD_PASSWORD" != "$DASHBOARD_PASSWORD_CONFIRM" ]; then
            print_error "Los passwords no coinciden"
            exit 1
        fi

        TRAEFIK_AUTH=$(htpasswd -nb admin "$DASHBOARD_PASSWORD" | sed -e s/\\$/\\$\\$/g)
        print_success "Hash generado automáticamente"
    else
        read -p "Ingresa el hash manualmente: " TRAEFIK_AUTH
    fi
else
    print_warning "htpasswd no está instalado"
    echo ""
    echo "Genera el hash en: https://hostingcanada.org/htpasswd-generator/"
    echo "Usuario: admin"
    read -s -p "Password deseado: " DASHBOARD_PASSWORD
    echo ""
    echo ""
    print_info "Abre el generador y usa estos valores:"
    echo "  Username: admin"
    echo "  Password: $DASHBOARD_PASSWORD"
    echo ""
    print_warning "IMPORTANTE: Reemplaza cada \$ por \$\$ en el resultado"
    echo ""
    read -p "Pega el hash aquí: " TRAEFIK_AUTH
fi

gh secret set TRAEFIK_DASHBOARD_AUTH -b "$TRAEFIK_AUTH" -R "$REPO"
print_success "TRAEFIK_DASHBOARD_AUTH configurado"
echo ""

# Resumen
print_header "Resumen de Configuración"

echo "Secrets configurados en: $REPO"
echo ""

gh secret list -R "$REPO" | grep -E "DOMAIN|ODOO_VERSION|ACME_EMAIL|POSTGRES_PASSWORD|TZ|TRAEFIK_DASHBOARD_AUTH" || true

echo ""
print_success "Todos los secrets configurados correctamente"
echo ""

# Verificación
print_header "Verificación"

echo "Verifica los secrets en GitHub:"
echo "  https://github.com/$REPO/settings/secrets/actions"
echo ""

print_info "Próximos pasos:"
echo "  1. Configura el self-hosted runner (ver .github/RUNNER_SETUP.md)"
echo "  2. Haz push de los workflows:"
echo "     git add .github/"
echo "     git commit -m \"Add GitHub Actions workflows\""
echo "     git push"
echo "  3. Crea un release para activar deployment:"
echo "     gh release create v1.0.0 --title \"Production Release v1.0.0\""
echo ""

print_success "Setup completado"
