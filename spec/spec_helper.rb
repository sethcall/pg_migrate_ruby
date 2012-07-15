require 'logging'

# bootstrap logger
Logging.logger.root.level = :debug
Logging.logger.root.appenders = Logging.appenders.stdout

require 'pg_migrate'
require 'pg_migrate/db_utility'
require 'files'
require 'fileutils'

target = File.join(File.dirname(__FILE__), '..', 'target')
FileUtils::rm_r(target, :force => true)

include PgMigrate
