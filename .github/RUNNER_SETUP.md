# Self-Hosted Runner Setup Guide

Guía completa para instalar y configurar un GitHub Actions self-hosted runner en tu VPS de producción.

---

## ¿Por Qué Self-Hosted Runner?

### Ventajas

✅ **Control total**: Tus workflows corren en tu infraestructura
✅ **Acceso directo**: Puede acceder a tus containers Docker localmente
✅ **Sin límites**: No hay límites de minutos como en runners de GitHub
✅ **Seguridad**: Los secrets no salen de tu infraestructura
✅ **Velocidad**: Deployment instantáneo sin transferir archivos

### Desventajas

⚠️ **Mantenimiento**: Debes mantener el servidor
⚠️ **Seguridad**: Debes asegurar el servidor correctamente
⚠️ **Disponibilidad**: Si el servidor cae, los workflows no funcionan

---

## Requisitos Previos

1. **VPS/Servidor** con Ubuntu 20.04+ o Debian 10+
2. **Docker** instalado y funcionando
3. **Acceso root** o sudo en el servidor
4. **GitHub** con permisos de admin en el repositorio

---

## Parte 1: Preparar el VPS

### 1.1. Actualizar el sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2. Instalar dependencias

```bash
sudo apt install -y \
  curl \
  git \
  jq \
  tar \
  build-essential \
  libssl-dev
```

### 1.3. Verificar Docker

```bash
docker --version
docker compose version
```

Si no está instalado:
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

---

## Parte 2: Crear Usuario para Runner

**Importante**: No ejecutar el runner como root.

### 2.1. Crear usuario dedicado

```bash
sudo useradd -m -s /bin/bash github-runner
sudo usermod -aG docker github-runner
```

### 2.2. Crear directorio de trabajo

```bash
sudo mkdir -p /home/github-runner/actions-runner
sudo chown -R github-runner:github-runner /home/github-runner
```

### 2.3. Dar permisos al proyecto Odoo

```bash
sudo chown -R github-runner:github-runner /home/geniusdev/WorkSpace/odoo
# O crear symlink
sudo ln -s /home/geniusdev/WorkSpace/odoo /home/github-runner/odoo
```

---

## Parte 3: Configurar Runner en GitHub

### 3.1. Obtener token de registro

1. Ve a tu repositorio en GitHub
2. Click en `Settings` → `Actions` → `Runners`
3. Click en `New self-hosted runner`
4. Selecciona `Linux` y `x64`
5. **Copia los comandos** que aparecen

**Ejemplo de comandos**:
```bash
# Download
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.319.1.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.319.1/actions-runner-linux-x64-2.319.1.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-2.319.1.tar.gz

# Configure (COPIAR EL COMANDO COMPLETO DE GITHUB)
./config.sh --url https://github.com/USUARIO/REPO --token ABCDEF...
```

### 3.2. Ejecutar configuración

**Cambiar a usuario github-runner**:
```bash
sudo su - github-runner
cd /home/github-runner/actions-runner
```

**Descargar runner** (usar versión de GitHub):
```bash
curl -o actions-runner-linux-x64-2.319.1.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.319.1/actions-runner-linux-x64-2.319.1.tar.gz

tar xzf ./actions-runner-linux-x64-2.319.1.tar.gz
```

**Configurar** (usar comando de GitHub):
```bash
./config.sh --url https://github.com/TU_USUARIO/TU_REPO --token TU_TOKEN
```

**Preguntas durante configuración**:
```
Enter the name of the runner group: [press Enter for default]
Enter the name of runner: production
Enter any additional labels: production,vps
Enter name of work folder: [press Enter for default]
```

### 3.3. Resultado esperado

```
√ Runner successfully added
√ Runner connection is good

# Runner settings
Runner name: production
Runner group name: Default
Labels: self-hosted, Linux, X64, production, vps
Work folder: _work
```

---

## Parte 4: Configurar Runner como Servicio

Para que el runner se inicie automáticamente al reiniciar el servidor.

### 4.1. Instalar servicio

**Como usuario github-runner**:
```bash
cd /home/github-runner/actions-runner
sudo ./svc.sh install github-runner
```

### 4.2. Iniciar servicio

```bash
sudo ./svc.sh start
```

### 4.3. Verificar estado

```bash
sudo ./svc.sh status
```

**Output esperado**:
```
● actions.runner.USUARIO-REPO.production.service - GitHub Actions Runner (USUARIO-REPO.production)
   Loaded: loaded
   Active: active (running)
```

### 4.4. Comandos del servicio

```bash
# Iniciar
sudo ./svc.sh start

# Detener
sudo ./svc.sh stop

# Estado
sudo ./svc.sh status

# Desinstalar servicio (no elimina runner)
sudo ./svc.sh uninstall
```

---

## Parte 5: Verificar Runner en GitHub

1. Ve a `Settings` → `Actions` → `Runners`
2. Deberías ver tu runner con estado **Idle** (esperando jobs)

**Ejemplo**:
```
Name: production
Status: Idle (green)
Labels: self-hosted, Linux, X64, production, vps
```

---

## Parte 6: Configurar Permisos de Docker

El runner necesita acceso a Docker sin sudo.

### 6.1. Verificar grupo docker

```bash
groups github-runner
# Debería incluir: docker
```

### 6.2. Si no está en grupo docker

```bash
sudo usermod -aG docker github-runner

# Reiniciar servicio del runner
sudo systemctl restart actions.runner.*
```

### 6.3. Test de permisos

```bash
sudo su - github-runner
docker ps
docker compose version
```

No debería pedir contraseña ni mostrar errores.

---

## Parte 7: Configurar Directorio de Trabajo

El runner necesita acceso al proyecto Odoo.

### 7.1. Opción A: Symlink (Recomendado)

```bash
sudo ln -s /home/geniusdev/WorkSpace/odoo /home/github-runner/odoo
sudo chown -h github-runner:github-runner /home/github-runner/odoo
```

### 7.2. Opción B: Cambiar ownership

```bash
sudo chown -R github-runner:github-runner /home/geniusdev/WorkSpace/odoo
```

### 7.3. Opción C: Configurar path en workflow

Modificar workflows para usar path específico:
```yaml
steps:
  - name: Navigate to project
    run: cd /home/geniusdev/WorkSpace/odoo
```

---

## Parte 8: Probar el Runner

### 8.1. Crear workflow de test

Crea `.github/workflows/test-runner.yml`:

```yaml
name: Test Self-Hosted Runner

on:
  workflow_dispatch:

jobs:
  test:
    runs-on:
      - self-hosted
      - production

    steps:
      - name: Check runner info
        run: |
          echo "Runner name: $RUNNER_NAME"
          echo "Runner OS: $RUNNER_OS"
          echo "Working directory: $(pwd)"
          echo "User: $(whoami)"

      - name: Check Docker
        run: |
          docker --version
          docker compose version
          docker ps

      - name: Check project access
        run: |
          ls -la /home/geniusdev/WorkSpace/odoo/
          cd /home/geniusdev/WorkSpace/odoo
          cat docker-compose.yml | head -10

      - name: Test completed
        run: |
          echo "✓ Runner is working correctly!"
```

### 8.2. Ejecutar workflow

1. Ve a `Actions` en GitHub
2. Selecciona `Test Self-Hosted Runner`
3. Click en `Run workflow`
4. Espera a que complete

### 8.3. Verificar logs

Deberías ver output similar a:
```
Runner name: production
Runner OS: Linux
Working directory: /home/github-runner/actions-runner/_work/odoo/odoo
User: github-runner
✓ Runner is working correctly!
```

---

## Parte 9: Seguridad del Runner

### 9.1. Firewall

```bash
# Permitir solo SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Verificar
sudo ufw status
```

### 9.2. Limitar acceso SSH

Edita `/etc/ssh/sshd_config`:
```
PermitRootLogin no
PasswordAuthentication no  # Solo usar keys
AllowUsers tu-usuario github-runner
```

Reiniciar SSH:
```bash
sudo systemctl restart sshd
```

### 9.3. Actualizar sistema automáticamente

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### 9.4. Monitoring

```bash
# Ver logs del runner
sudo journalctl -u actions.runner.* -f

# Ver logs de sistema
sudo tail -f /var/log/syslog
```

---

## Parte 10: Mantenimiento

### 10.1. Actualizar runner

```bash
sudo su - github-runner
cd /home/github-runner/actions-runner

# Detener servicio
sudo ./svc.sh stop

# Descargar nueva versión (ver GitHub para latest)
curl -o actions-runner-linux-x64-NEW_VERSION.tar.gz -L \
  https://github.com/actions/runner/releases/download/vNEW_VERSION/actions-runner-linux-x64-NEW_VERSION.tar.gz

# Extraer
tar xzf ./actions-runner-linux-x64-NEW_VERSION.tar.gz

# Iniciar servicio
sudo ./svc.sh start
```

### 10.2. Ver logs

```bash
# Logs del servicio
sudo journalctl -u actions.runner.* -f

# Logs del runner
cd /home/github-runner/actions-runner
tail -f _diag/*.log
```

### 10.3. Limpiar trabajo antiguo

```bash
cd /home/github-runner/actions-runner/_work
rm -rf */_actions  # Limpia caché de actions
```

### 10.4. Eliminar runner

**En GitHub**:
1. `Settings` → `Actions` → `Runners`
2. Click en tu runner → `Remove`

**En el servidor**:
```bash
cd /home/github-runner/actions-runner

# Detener servicio
sudo ./svc.sh stop
sudo ./svc.sh uninstall

# Remover configuración
./config.sh remove --token TU_TOKEN
```

---

## Troubleshooting

### Runner no aparece en GitHub

**Problema**: Runner instalado pero no visible

**Solución**:
```bash
# Verificar servicio
sudo systemctl status actions.runner.*

# Ver logs
sudo journalctl -u actions.runner.* -n 50

# Reiniciar
sudo systemctl restart actions.runner.*
```

### "Permission denied" con Docker

**Problema**: Runner no puede ejecutar comandos Docker

**Solución**:
```bash
# Agregar a grupo docker
sudo usermod -aG docker github-runner

# Reiniciar servicio
sudo systemctl restart actions.runner.*

# Verificar
sudo su - github-runner
docker ps
```

### Workflow falla con "No such file or directory"

**Problema**: Runner no encuentra el proyecto

**Solución**:
```bash
# Opción 1: Checkout del código en workflow
steps:
  - name: Checkout
    uses: actions/checkout@v4

# Opción 2: Usar path absoluto
steps:
  - name: Deploy
    run: |
      cd /home/geniusdev/WorkSpace/odoo
      docker compose up -d
```

### Runner se desconecta frecuentemente

**Problema**: Runner pierde conexión con GitHub

**Solución**:
```bash
# Verificar conectividad
curl -I https://api.github.com

# Ver logs
sudo journalctl -u actions.runner.* -f

# Verificar proxy/firewall
```

---

## Checklist de Instalación

- [ ] VPS preparado (Ubuntu/Debian actualizado)
- [ ] Docker instalado y funcionando
- [ ] Usuario `github-runner` creado
- [ ] Usuario en grupo `docker`
- [ ] Runner descargado de GitHub
- [ ] Runner configurado con labels `production`
- [ ] Servicio instalado y corriendo
- [ ] Runner visible en GitHub (estado Idle)
- [ ] Test workflow ejecutado exitosamente
- [ ] Firewall configurado
- [ ] SSH asegurado
- [ ] Logs funcionando

---

## Arquitectura Final

```
GitHub Actions
      │
      │ (trigger workflow)
      ▼
┌─────────────────┐
│  GitHub Repo    │
└────────┬────────┘
         │
         │ (webhook)
         ▼
┌─────────────────┐
│  VPS Runner     │ (self-hosted, production)
│  github-runner  │
└────────┬────────┘
         │
         │ (docker compose commands)
         ▼
┌─────────────────┐
│  Odoo Stack     │
│  - Traefik      │
│  - Odoo         │
│  - PostgreSQL   │
└─────────────────┘
```

---

## Comandos Rápidos de Referencia

```bash
# Ver estado del runner
sudo systemctl status actions.runner.*

# Reiniciar runner
sudo systemctl restart actions.runner.*

# Ver logs en vivo
sudo journalctl -u actions.runner.* -f

# Cambiar a usuario runner
sudo su - github-runner

# Ver runners en GitHub (CLI)
gh api /repos/OWNER/REPO/actions/runners

# Test de Docker
docker ps && docker compose version
```

---

## Próximos Pasos

Una vez que el runner esté funcionando:

1. ✅ Configurar secrets en GitHub (ver `SECRETS.md`)
2. ✅ Hacer push de código para activar workflows
3. ✅ Crear un release para activar deployment automático
4. ✅ Configurar backups automáticos
5. ✅ Configurar monitoring y alertas

---

**Estado**: ✅ Runner configurado y listo para CI/CD automático

**Última actualización**: 2024-11-30
