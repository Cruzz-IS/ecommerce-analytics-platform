
.PHONY: up down ps schemas raw

# Levantar PostgreSQL
up:
	docker compose up -d

# Detener contenedores
down:
	docker compose down

# Ver estado de los servicios
ps:
	docker compose ps

# Crear esquemas
schemas:
	docker compose exec -T db psql -U admin -d ecommerce < sql/01_schemas.sql

# Crear tablas RAW
raw:
	docker compose exec -T db psql -U admin -d ecommerce < sql/02_raw.sql


# Ingestar los CSV a RAW
ingest:
	python scripts/load_raw.py

# Crear vistas de STAGING
staging:
	docker compose exec -T db psql -U admin -d ecommerce < sql/03_staging.sql

# Crear vistas de MARTS
marts:
	docker compose exec -T db psql -U admin -d ecommerce < sql/04_marts.sql

