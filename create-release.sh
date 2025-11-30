#!/bin/bash

###############################################################################
# Create Release Script
# Crea releases de GitHub que activan el workflow de deployment automático
###############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones
print_header() {
    echo ""
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
    echo -e "${CYAN}ℹ${NC} $1"
}

# Verificar GitHub CLI
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI no encontrado"
    echo ""
    print_info "Instala GitHub CLI desde: https://cli.github.com/"
    exit 1
fi

# Verificar autenticación
if ! gh auth status &> /dev/null; then
    print_error "No autenticado con GitHub"
    print_info "Ejecuta: gh auth login"
    exit 1
fi

# Verificar que estamos en un repositorio git
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    print_error "No estás en un repositorio git"
    exit 1
fi

print_header "Create Release - CI/CD Trigger"

# Obtener información del repositorio
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ -z "$REPO" ]; then
    print_error "No se pudo detectar el repositorio"
    exit 1
fi

print_success "Repositorio: $REPO"
print_success "Branch actual: $BRANCH"

# Verificar que estamos en main/master
if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    print_warning "No estás en main/master, estás en: $BRANCH"
    read -p "¿Quieres continuar de todos modos? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Proceso cancelado"
        exit 0
    fi
fi

# Verificar que no hay cambios sin commit
if ! git diff-index --quiet HEAD --; then
    print_warning "Hay cambios sin commit"
    git status --short
    echo ""
    read -p "¿Quieres hacer commit de los cambios? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Mensaje del commit: " COMMIT_MSG
        git add .
        git commit -m "$COMMIT_MSG"
        print_success "Commit realizado"
    else
        print_warning "Continuando con cambios sin commit"
    fi
fi

# Verificar cambios pendientes de push
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")

if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
    print_warning "Hay commits locales sin push"
    read -p "¿Quieres hacer push ahora? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push
        print_success "Push realizado"
    fi
fi

echo ""
print_header "Información del Release"

# Obtener último tag/release
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_TAG" ]; then
    print_info "Último release: $LAST_TAG"

    # Sugerir siguiente versión
    VERSION_PARTS=(${LAST_TAG//v/})
    VERSION_PARTS=(${VERSION_PARTS//./ })

    MAJOR=${VERSION_PARTS[0]:-0}
    MINOR=${VERSION_PARTS[1]:-0}
    PATCH=${VERSION_PARTS[2]:-0}

    NEXT_PATCH="v${MAJOR}.${MINOR}.$((PATCH + 1))"
    NEXT_MINOR="v${MAJOR}.$((MINOR + 1)).0"
    NEXT_MAJOR="v$((MAJOR + 1)).0.0"

    echo ""
    print_info "Versiones sugeridas:"
    echo "  1. $NEXT_PATCH (patch - bug fixes)"
    echo "  2. $NEXT_MINOR (minor - new features)"
    echo "  3. $NEXT_MAJOR (major - breaking changes)"
    echo "  4. Custom (ingresar manualmente)"
    echo ""

    read -p "Selecciona opción (1-4): " VERSION_CHOICE

    case $VERSION_CHOICE in
        1) NEW_VERSION=$NEXT_PATCH ;;
        2) NEW_VERSION=$NEXT_MINOR ;;
        3) NEW_VERSION=$NEXT_MAJOR ;;
        4)
            read -p "Ingresa versión (formato: v1.0.0): " NEW_VERSION
            ;;
        *)
            print_error "Opción inválida"
            exit 1
            ;;
    esac
else
    print_warning "No hay releases previos"
    read -p "Ingresa la versión inicial (ej: v1.0.0): " NEW_VERSION
fi

# Validar formato de versión
if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Formato de versión inválido. Usa formato: v1.0.0"
    exit 1
fi

print_success "Nueva versión: $NEW_VERSION"

# Título del release
echo ""
read -p "Título del release (default: Production Release $NEW_VERSION): " RELEASE_TITLE
RELEASE_TITLE=${RELEASE_TITLE:-"Production Release $NEW_VERSION"}

# Notas del release
echo ""
print_info "Notas del release (presiona Ctrl+D cuando termines):"
print_info "Ejemplo:"
echo "## What's New"
echo "- Feature: Nueva funcionalidad X"
echo "- Fix: Corrección de bug Y"
echo "- Improvement: Optimización de Z"
echo ""

RELEASE_NOTES=$(cat)

if [ -z "$RELEASE_NOTES" ]; then
    # Generar notas automáticas desde commits
    if [ -n "$LAST_TAG" ]; then
        print_info "Generando notas automáticas desde commits..."
        RELEASE_NOTES=$(git log ${LAST_TAG}..HEAD --pretty=format:"- %s" --no-merges)
    else
        RELEASE_NOTES="Initial release"
    fi
fi

# Agregar footer automático
RELEASE_NOTES="$RELEASE_NOTES

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

**Deployment**: Este release activará el workflow de deployment automático a producción.
**Monitor**: https://github.com/$REPO/actions"

# Confirmación
echo ""
print_header "Confirmación"
echo -e "${CYAN}Versión:${NC} $NEW_VERSION"
echo -e "${CYAN}Título:${NC} $RELEASE_TITLE"
echo -e "${CYAN}Branch:${NC} $BRANCH"
echo -e "${CYAN}Repositorio:${NC} $REPO"
echo ""
echo -e "${CYAN}Notas del release:${NC}"
echo "$RELEASE_NOTES"
echo ""

read -p "¿Crear release y activar deployment? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Proceso cancelado"
    exit 0
fi

# Crear release
print_info "Creando release $NEW_VERSION..."

if gh release create "$NEW_VERSION" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    --target "$BRANCH"; then

    echo ""
    print_success "Release creado exitosamente!"
    echo ""
    print_info "El workflow de deployment se ha activado automáticamente"
    print_info "Puedes monitorearlo en:"
    echo ""
    echo -e "  ${CYAN}https://github.com/$REPO/actions${NC}"
    echo ""

    # Preguntar si quiere monitorear
    read -p "¿Quieres monitorear el deployment en vivo? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Iniciando monitor de workflow..."
        sleep 2
        gh run watch
    else
        print_info "Para monitorear manualmente ejecuta:"
        echo "  gh run list"
        echo "  gh run watch"
    fi
else
    print_error "Error al crear release"
    exit 1
fi

echo ""
print_success "Proceso completado"
