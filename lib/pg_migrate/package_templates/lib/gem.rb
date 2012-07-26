require '<%= name %>/version'
require 'pg_migrate'

module <%= constant_name %>

  class Migrator
    def migrate options={}
      pgMigrator = PgMigrate::Migrator.new(PgMigrate::ManifestReader.new, PgMigrate::SqlReader.new, options)
      pgMigrator.migrate(File.expand_path('../<%= name %>/schemas', __FILE__))
    end
  end
end
