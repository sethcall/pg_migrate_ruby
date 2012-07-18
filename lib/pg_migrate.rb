require 'logging'
require 'pg'
require 'thor'
require "pg_migrate/version"
require "pg_migrate/migration"
require "pg_migrate/sql_reader"
require "pg_migrate/manifest_reader"
require "pg_migrate/migrator"
require "pg_migrate/config_parser"
require "pg_migrate/builder"
require "pg_migrate/command_line"

# name of the manifest file
MANIFEST_FILENAME = 'manifest'
# name of the 'forward' migration folder
UP_DIRNAME = 'up'
# name of the 'backwards' migration folder
DOWN_DIRNAME = 'down'
# name of the 'test' migration folder
TESTDIRNAME = 'test'
# name of the bootstrap.sql file
BOOTSTRAP_FILENAME = "bootstrap.sql"
# built manifest version header
BUILDER_VERSION_HEADER="# pg_migrate-"


### SQL CONSTANTS ###
PG_MIGRATE_TABLE = "pg_migrate"
PG_MIGRATIONS_TABLE = "pg_migrations"



module PgMigrate
  # Your code goes here...
end
