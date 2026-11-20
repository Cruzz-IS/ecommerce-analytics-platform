
.PHONY: up down ps schemas raw gen load staging marts bi export pipeline

# Configuracion de PostgreSQL
PG_USER ?= admin
PG_DB ?= ecommerce

# Configuracion de generacion de datos
ORDERS ?= 100000
CUSTOMERS ?= 20000
PRODUCTS ?= 500
SEED ?= 42

# Comando de conexion a PostgreSQL dentro de Docker
PSQL = docker compose exec -T db psql -v ON_ERROR_STOP=1 -U $(PG_USER) -d $(PG_DB)


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
	$(PSQL) < sql/01_schemas.sql

# Crear tablas RAW
raw:
	$(PSQL) < sql/02_raw.sql


# Generar datos CSV
gen:
	python -m pipelines.generate_data --orders $(ORDERS) --customers $(CUSTOMERS) --products $(PRODUCTS) --seed $(SEED)

# Ingestar los CSV a PostgreSQL RAW
load:
	python -m pipelines.load_raw


# Crear vistas de STAGING
staging:
	$(PSQL) < sql/03_staging.sql

# Crear tablas de MARTS
marts:
	$(PSQL) < sql/04_marts.sql

# Crear objetos de BI en PostgreSQL
bi:
	$(PSQL) < sql/05_bi.sql

# Exportar datos para herramientas BI
export:
	python -m pipelines.export_for_bi


# Ejecutar el pipeline completo
pipeline: schemas raw gen load staging marts bi
