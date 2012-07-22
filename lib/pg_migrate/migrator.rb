module PgMigrate

  class Migrator

    attr_accessor :conn, :connection_hash, :manifest_path, :manifest, :manifest_reader, :sql_reader

    # options = gem 'pg' connection_hash options, or connstring => dbname=test port=5432, or pgconn => PG::Connection object
    def initialize(manifest_reader, sql_reader, options = {})
      @log = Logging.logger[self]
      @connection_hash = options
      @manifest = nil
      @builder_version = nil
      @manifest_reader = manifest_reader
      @sql_reader = sql_reader
    end

    # 'migrate' attempt to migrate your database based on the contents of your built manifest
    # The manifest_path argument should point to your manifest
    # manifest_path = the directory containing your 'manifest' file, 'up' directory, 'down' directory, 'test' directory
    # this method will throw an exception if anything goes wrong (such as bad SQL in the migrations themselves)

    def migrate(manifest_path)
      @manifest_path = manifest_path

      if !@connection_hash[:pgconn].nil?
        @conn = @connection_hash[:pgconn]
      elsif !@connection_hash[:connstring].nil?
        @conn = PG::Connection.open(@connection_hash[:connstring])
      else
        @conn = PG::Connection.open(@connection_hash)
      end

      # this is used to record the version of the 'migrator' in the pg_migrate table
      @conn.exec("SET application_name = 'pg_migrate_ruby-#{PgMigrate::VERSION}'")

      # load the manifest, and version of the builder that made it
      process_manifest()

      # execute the migrations
      run_migrations()
    end


    # load the manifest's migration declarations, and validate that each migration points to a real file
    def process_manifest
      @manifest, @builder_version = @manifest_reader.load_output_manifest(@manifest_path)
      @manifest_reader.validate_migration_paths(@manifest_path, @manifest)
    end

    # run all necessary migrations
    def run_migrations

      # run bootstrap before user migrations to prepare database
      run_bootstrap

      # loop through the manifest, executing migrations in turn
      manifest.each_with_index do |migration, index|
        execute_migration(migration.name, migration.filepath)
      end

    end

    # executes the bootstrap method
    def run_bootstrap
      bootstrap = File.join(@manifest_path, UP_DIRNAME, BOOTSTRAP_FILENAME)
      execute_migration('bootstrap.sql', bootstrap)
    end

    # execute a single migration by loading it's statements from file, and then executing each
    def execute_migration(name, filepath)
      @log.debug "executing migration #{filepath}"

      statements = @sql_reader.load_migration(filepath)
      if statements.length == 0
        raise 'no statements found in migration #{filepath}'
      end
      run_migration(name, statements)
    end

    # execute all the statements of a single migration
    def run_migration(name, statements)

      begin
        statements.each do |statement|
          conn.exec(statement).clear
        end
      rescue Exception => e
        # we make a special allowance for one exception; it just means this migration
        # has already occurred, and we should just treat it like a continue
        if e.message.index('pg_migrate: code=migration_exists').nil?
          conn.exec("ROLLBACK")
          raise e
        else
          conn.exec("ROLLBACK")
          @log.info "migration #{name} already run"
        end
      end
    end
  end
end

