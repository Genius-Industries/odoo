#!/bin/bash

#############################################
# Setup GitHub Secrets for Workflows
# Script interactivo para configurar secrets
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if gh CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) no está instalado"
        echo ""
        echo "Instala GitHub CLI:"
        echo "  macOS:   brew install gh"
        echo "  Linux:   https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        echo "  Windows: https://github.com/cli/cli#windows"
        exit 1
    fi
}

# Check if logged in to gh
check_gh_auth() {
    if ! gh auth status &> /dev/null; then
        print_error "No estás autenticado en GitHub CLI"
        echo ""
        print_info "Ejecuta: gh auth login"
        exit 1
    fi
}

# Generate SSH key
generate_ssh_key() {
    print_header "Generar SSH Key para GitHub Actions"

    local key_path="$HOME/.ssh/github_deploy_key"

    if [ -f "$key_path" ]; then
        read -p "Ya existe una key en $key_path. ¿Sobrescribir? (y/N): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            print_info "Usando key existente"
            return
        fi
    fi

    print_info "Generando nueva SSH key..."
    ssh-keygen -t ed25519 -C "github-actions-deploy" -f "$key_path" -N ""

    print_success "SSH key generada en: $key_path"
    echo ""
    print_info "Copia esta llave pública al servidor:"
    echo ""
    cat "${key_path}.pub"
    echo ""
    read -p "Presiona ENTER cuando hayas copiado la llave al servidor..."
}

# Generate Traefik auth hash
generate_traefik_auth() {
    print_header "Generar Hash de Autenticación Traefik"

    if ! command -v htpasswd &> /dev/null; then
        print_warning "htpasswd no está instalado"
        echo ""
        echo "Instálalo con:"
        echo "  Debian/Ubuntu: sudo apt-get install apache2-utils"
        echo "  macOS: Ya viene instalado"
        echo ""
        echo "O usa el generador online:"
        echo "  https://hostingcanada.org/htpasswd-generator/"
        echo ""
        read -p "¿Ya tienes el hash? Pégalo aquí: " hash
        # Duplicar $ para docker-compose
        echo "${hash//$/$$}"
        return
    fi

    read -p "Usuario [admin]: " username
    username=${username:-admin}

    read -sp "Password: " password
    echo ""

    # Generar hash y duplicar $ para docker-compose
    local hash=$(htpasswd -nb "$username" "$password")
    echo "${hash//$/$$}"
}

# Main script
main() {
    print_header "Configuración de GitHub Secrets"
    echo ""

    # Check requirements
    check_gh_cli
    check_gh_auth

    print_success "GitHub CLI está configurado correctamente"
    echo ""

    # Get current repository
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)

    if [ -z "$repo" ]; then
        print_error "No se detectó un repositorio de GitHub"
        print_info "Ejecuta este script desde el directorio del repositorio"
        exit 1
    fi

    print_info "Repositorio: $repo"
    echo ""

    # Confirm
    read -p "¿Configurar secrets para este repositorio? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_info "Operación cancelada"
        exit 0
    fi

    echo ""
    print_header "Configuración de Secrets"
    echo ""

    # SSH Configuration
    print_info "1. Configuración SSH"
    echo ""

    read -p "¿Generar nueva SSH key? (y/N): " gen_key
    if [[ $gen_key =~ ^[Yy]$ ]]; then
        generate_ssh_key
    fi

    echo ""
    read -p "SSH Host (IP o dominio): " ssh_host
    read -p "SSH User: " ssh_user
    read -p "Ruta a SSH private key [$HOME/.ssh/github_deploy_key]: " ssh_key_path
    ssh_key_path=${ssh_key_path:-$HOME/.ssh/github_deploy_key}

    if [ ! -f "$ssh_key_path" ]; then
        print_error "No se encuentra la llave privada: $ssh_key_path"
        exit 1
    fi

    # Domain Configuration
    echo ""
    print_info "2. Configuración de Dominio"
    echo ""

    read -p "Dominio (ej: odoo.example.com): " domain
    read -p "Email para Let's Encrypt: " acme_email

    # Database Configuration
    echo ""
    print_info "3. Configuración de Base de Datos"
    echo ""

    read -sp "PostgreSQL Password: " postgres_password
    echo ""

    # Traefik Configuration
    echo ""
    print_info "4. Configuración de Traefik"
    echo ""

    read -p "¿Generar hash de autenticación Traefik? (y/N): " gen_hash
    if [[ $gen_hash =~ ^[Yy]$ ]]; then
        traefik_auth=$(generate_traefik_auth)
    else
        read -p "Traefik Dashboard Auth (hash): " traefik_auth
    fi

    # S3 Configuration (optional)
    echo ""
    print_info "5. Configuración S3 (Opcional - Enter para omitir)"
    echo ""

    read -p "AWS Access Key ID: " aws_key
    read -sp "AWS Secret Access Key: " aws_secret
    echo ""
    read -p "S3 Bucket Name: " s3_bucket

    # Summary
    echo ""
    print_header "Resumen de Configuración"
    echo ""
    echo "Repository: $repo"
    echo "SSH Host: $ssh_host"
    echo "SSH User: $ssh_user"
    echo "Domain: $domain"
    echo "ACME Email: $acme_email"
    echo "Postgres Password: ********"
    echo "Traefik Auth: ${traefik_auth:0:20}..."

    if [ -n "$aws_key" ]; then
        echo "AWS Key ID: ${aws_key:0:10}..."
        echo "S3 Bucket: $s3_bucket"
    fi

    echo ""
    read -p "¿Confirmar y configurar secrets? (y/N): " final_confirm
    if [[ ! $final_confirm =~ ^[Yy]$ ]]; then
        print_info "Operación cancelada"
        exit 0
    fi

    # Set secrets
    echo ""
    print_header "Configurando Secrets..."
    echo ""

    print_info "Configurando SSH_HOST..."
    gh secret set SSH_HOST --body "$ssh_host"

    print_info "Configurando SSH_USER..."
    gh secret set SSH_USER --body "$ssh_user"

    print_info "Configurando SSH_PRIVATE_KEY..."
    gh secret set SSH_PRIVATE_KEY < "$ssh_key_path"

    print_info "Configurando DOMAIN..."
    gh secret set DOMAIN --body "$domain"

    print_info "Configurando ACME_EMAIL..."
    gh secret set ACME_EMAIL --body "$acme_email"

    print_info "Configurando POSTGRES_PASSWORD..."
    gh secret set POSTGRES_PASSWORD --body "$postgres_password"

    print_info "Configurando TRAEFIK_DASHBOARD_AUTH..."
    gh secret set TRAEFIK_DASHBOARD_AUTH --body "$traefik_auth"

    if [ -n "$aws_key" ]; then
        print_info "Configurando AWS_ACCESS_KEY_ID..."
        gh secret set AWS_ACCESS_KEY_ID --body "$aws_key"

        print_info "Configurando AWS_SECRET_ACCESS_KEY..."
        gh secret set AWS_SECRET_ACCESS_KEY --body "$aws_secret"

        print_info "Configurando BACKUP_BUCKET..."
        gh secret set BACKUP_BUCKET --body "$s3_bucket"

        print_info "Configurando ENABLE_S3_BACKUP variable..."
        gh variable set ENABLE_S3_BACKUP --body "true"
    fi

    echo ""
    print_success "¡Todos los secrets configurados correctamente!"
    echo ""

    print_header "Próximos Pasos"
    echo ""
    echo "1. Verifica los secrets en GitHub:"
    echo "   Settings → Secrets and variables → Actions"
    echo ""
    echo "2. Prepara el servidor de producción:"
    echo "   ssh $ssh_user@$ssh_host"
    echo "   sudo mkdir -p /opt/odoo"
    echo "   cd /opt/odoo"
    echo "   git clone https://github.com/$repo.git ."
    echo ""
    echo "3. Ejecuta un test de deployment:"
    echo "   Actions → Deploy to Production → Run workflow"
    echo ""

    print_success "Configuración completa!"
}

# Run main
main
