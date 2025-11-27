.PHONY: help start stop restart logs clean backup

help: ## Muestra esta ayuda
	@echo "Comandos disponibles para Odoo + Traefik:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Inicializa el proyecto (crea .env y permisos)
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ Archivo .env creado. Edítalo antes de continuar."; \
		echo "   nano .env"; \
	else \
		echo "⚠️  .env ya existe"; \
	fi
	@chmod 600 traefik/acme.json
	@echo "✅ Permisos configurados"

network: ## Crea la red de Traefik
	@docker network create traefik-network 2>/dev/null || echo "✅ Red traefik-network ya existe"

traefik: network ## Inicia solo Traefik
	docker compose -f docker-compose.traefik.yml up -d
	@echo "✅ Traefik iniciado"

start: network ## Inicia todos los servicios
	docker compose -f docker-compose.traefik.yml up -d
	@sleep 3
	docker compose up -d
	@echo "✅ Todos los servicios iniciados"

stop: ## Detiene todos los servicios
	docker compose down
	docker compose -f docker-compose.traefik.yml down
	@echo "✅ Servicios detenidos"

restart: ## Reinicia todos los servicios
	docker compose restart
	@echo "✅ Servicios reiniciados"

logs: ## Muestra logs de todos los servicios
	docker compose logs -f

logs-odoo: ## Muestra logs de Odoo
	docker logs -f odoo_app

logs-db: ## Muestra logs de PostgreSQL
	docker logs -f odoo_db

logs-traefik: ## Muestra logs de Traefik
	docker logs -f traefik

status: ## Muestra el estado de los servicios
	@echo "=== Servicios Docker ==="
	@docker compose ps
	@echo ""
	@docker compose -f docker-compose.traefik.yml ps

shell-odoo: ## Abre shell en contenedor Odoo
	docker exec -it odoo_app /bin/bash

shell-db: ## Abre shell PostgreSQL
	docker exec -it odoo_db psql -U odoo

backup-db: ## Crea backup de la base de datos
	@mkdir -p backups
	docker exec odoo_db pg_dump -U odoo odoo > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "✅ Backup creado en backups/"

backup-volumes: ## Crea backup de volúmenes
	@mkdir -p backups
	docker run --rm -v odoo-web-data:/data -v $$(pwd)/backups:/backup ubuntu tar czf /backup/odoo-data_$$(date +%Y%m%d_%H%M%S).tar.gz /data
	@echo "✅ Backup de volúmenes creado"

restore-db: ## Restaura base de datos (uso: make restore-db FILE=backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Especifica el archivo: make restore-db FILE=backups/backup.sql"; \
		exit 1; \
	fi
	docker exec -i odoo_db psql -U odoo odoo < $(FILE)
	@echo "✅ Base de datos restaurada"

clean: stop ## Detiene y elimina contenedores y volúmenes
	docker compose down -v
	@echo "⚠️  Volúmenes eliminados"

update: ## Actualiza las imágenes
	docker compose pull
	docker compose -f docker-compose.traefik.yml pull
	@echo "✅ Imágenes actualizadas"

install-addons: ## Clona módulos OCA (ejemplo)
	@echo "Clonando módulos OCA de ejemplo..."
	@cd addons && git clone https://github.com/OCA/web.git --branch 17.0 --depth 1 --single-branch || true
	@echo "✅ Reinicia Odoo: make restart"
