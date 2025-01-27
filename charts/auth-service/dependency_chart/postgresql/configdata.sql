SELECT 'CREATE DATABASE ory '
'WITH '
'ENCODING = ''UTF8'' '
'CONNECTION LIMIT = -1 '
'IS_TEMPLATE = False'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ory')\gexec
SELECT 'CREATE DATABASE auth '
       'WITH '
       'ENCODING = ''UTF8'' '
       'CONNECTION LIMIT = -1 '
       'IS_TEMPLATE = False'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'auth')\gexec
\c auth
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS "auth_service_data";

-- Table: "auth_service_data".organizations
CREATE TABLE IF NOT EXISTS "auth_service_data".organizations
(
    org_id uuid NOT NULL DEFAULT uuid_generate_v1(),
    org_name character varying(50) COLLATE pg_catalog."default" NOT NULL,
    external_idp boolean NOT NULL DEFAULT false,
    CONSTRAINT organizations_pkey PRIMARY KEY (org_id)
);
ALTER TABLE "auth_service_data".organizations 
ADD COLUMN IF NOT EXISTS external_id character varying(100);
ALTER TABLE "auth_service_data".organizations 
ALTER COLUMN external_id TYPE uuid USING external_id::uuid;
UPDATE "auth_service_data".organizations 
SET external_id = uuid_generate_v1()
WHERE external_id IS NULL;
ALTER TABLE "auth_service_data".organizations 
ALTER COLUMN external_id SET NOT NULL;
ALTER TABLE "auth_service_data".organizations 
ALTER COLUMN external_id DROP DEFAULT;

-- Table: "auth_service_data".domains
CREATE TABLE IF NOT EXISTS "auth_service_data".domains
(
    domain_name character varying(100) COLLATE pg_catalog."default" NOT NULL,
    org_id uuid NOT NULL,
    CONSTRAINT domains_pkey PRIMARY KEY (domain_name, org_id),
    CONSTRAINT domain_org_fk FOREIGN KEY (org_id)
        REFERENCES "auth_service_data".organizations (org_id) MATCH SIMPLE
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);
-- Service User and permissions
DO
$createUser$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'auth_service') THEN
      RAISE NOTICE 'Role "auth_service" already exists. Skipping.';
   ELSE
      BEGIN   -- nested block
        CREATE ROLE "auth_service" WITH
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOINHERIT
            NOREPLICATION
            CONNECTION LIMIT -1
            PASSWORD 'CHANGE-THIS-SECRET';
        GRANT SELECT,INSERT,UPDATE,DELETE
        ON ALL TABLES
        IN SCHEMA "auth_service_data"
        TO "auth_service";
        GRANT USAGE
        ON SCHEMA "auth_service_data"
        TO "auth_service";
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role "auth_service" was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
$createUser$;