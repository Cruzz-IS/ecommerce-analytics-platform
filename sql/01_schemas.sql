-- Crear usuario de solo lectura para BI
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'bi_reader'
    ) THEN
       CREATE ROLE bi_reader LOGIN;
    END IF;
END
$$;


ALTER ROLE bi_reader SET default_transaction_read_only = on;

-- Crear esquemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;
CREATE SCHEMA IF NOT EXISTS bi;

-- Permisos BI
GRANT USAGE ON SCHEMA bi TO bi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA bi TO bi_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA bi
GRANT SELECT ON TABLES TO bi_reader;

