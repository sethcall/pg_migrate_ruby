require 'pathname'
require 'fileutils'
require 'find'
require 'erb'


module PgMigrate
  # takes a unprocessed manifest directory, and adds before/after headers to each file
  class Builder

    attr_accessor :manifest_reader, :sql_reader, :loaded_manifest

    def initialize(manifest_reader, sql_reader)
      @log = Logging.logger[self]
      @manifest_reader = manifest_reader
      @sql_reader = sql_reader
      @template_dir = File.join(File.dirname(__FILE__), 'templates')
    end


    # input_dir is root path, contains file 'manifest' and 'migrations'
    # output_dir will have a manifest and migrations folder, but processed
    # force will create the output dir if needed, and *delete an existing directory* if it's in the way
    # test will run tests
    def build(input_dir, output_dir, options={:force=>true, :test=>false})
      input_dir = File.expand_path(input_dir)
      output_dir = File.expand_path(output_dir)

      if input_dir == output_dir
        raise 'input_dir can not be same as output_dir: #{input_dir}'
      end

      @log.debug "building migration directory #{input_dir} and placing result at: #{output_dir}"

      output = Pathname.new(output_dir)
      if !output.exist?
        if !options[:force]
          raise "Output directory '#{output_dir}' does not exist.  Create it or specify force=true"
        else
          output.mkpath
        end
      else
        # verify that it's is a directory
        if !output.directory?
          raise "output_dir #{output_dir} is a file; not a directory."
        else
          @log.debug("deleting & recreating existing output_dir #{output_dir}")
          output.rmtree
          output.mkpath
        end
      end

      # manifest always goes over mostly as-is,
      # just with a comment added at top indicating our version

      input_manifest = File.join(input_dir, MANIFEST_FILENAME)
      output_manifest = File.join(output_dir, MANIFEST_FILENAME)

      File.open(output_manifest, 'w') do |fout|
        fout.puts "#{BUILDER_VERSION_HEADER}pg_migrate_ruby-#{PgMigrate::VERSION}"
        IO.readlines(input_manifest).each do |input|
          fout.puts input
        end
      end

      # if .pg_migrate file exists, copy it
      input_pg_config = File.join(input_dir, PG_CONFIG)
      if FileTest::exist? input_pg_config
        output_pg_config = File.join(output_dir, PG_CONFIG)

        File.open(output_pg_config, 'w') do |fout|
          IO.readlines(input_pg_config).each do |input|
            fout.puts input
          end
        end
      end

      # in order array of manifest declarations
      @loaded_manifest = @manifest_reader.load_input_manifest(input_dir)
      # hashed on migration name hash of manifest

      loaded_manifest_hash = @manifest_reader.hash_loaded_manifest(loaded_manifest)
      @manifest_reader.validate_migration_paths(input_dir, loaded_manifest)

      build_up(input_dir, output_dir, loaded_manifest_hash, loaded_manifest)
    
      # ok we are done. time to test!
      if options[:test]
        test(output_dir, options)
      end
    end

    def build_up(input_dir, output_dir, loaded_manifest_hash, loaded_manifest)
      migrations_input = File.join(input_dir, UP_DIRNAME)
      migrations_output = File.join(output_dir, UP_DIRNAME)

      if(!FileTest::exist? migrations_input)
        raise "'up' directory must exist at #{migrations_input}"
      end

      # iterate through files in input migrations path, wrapping files with transactions and other required bits

      Find.find(migrations_input) do |path|
        if path == ".."
          Find.prune
        else
          @log.debug "building #{path}"

          # create relative bit
          relative_path = path[migrations_input.length..-1]

          # create the filename correct for the input directory, for this file
          migration_in_path = path

          # create the filename correct for the output directory, for this file
          migration_out_path = File.join(migrations_output, relative_path)

          process_and_copy_up(migration_in_path, migration_out_path, relative_path, loaded_manifest_hash, loaded_manifest)
        end
      end

      create_bootstrap_script(migrations_output)
    end

    # creates the 'pg_migrations table'
    def create_bootstrap_script(migration_out_path)
      @log.debug "creating bootstrap script #{migration_out_path}"
      run_template("bootstrap.erb", binding, File.join(migration_out_path, BOOTSTRAP_FILENAME))
    end

    def create_wrapped_up_migration(migration_in_filepath, migration_out_filepath, migration_def, loaded_manifest)
      @log.debug "securing migration #{migration_def.name}"
      
      builder_version="pg_migrate_ruby-#{PgMigrate::VERSION}"
      manifest_version=loaded_manifest[-1].ordinal
      migration_content = nil
      File.open(migration_in_filepath, 'r') { |reader| migration_content = reader.read }
      run_template("up.erb", binding, File.join(migration_out_filepath))
    end

    # given an input template and binding, writes to an output file
    def run_template(template, binding, output_filepath)
      bootstrap_template = nil
      File.open(File.join(@template_dir, template), 'r') do |reader|
        bootstrap_template   = reader.read
      end


      template = ERB.new(bootstrap_template, 0, "%<>")
      content = template.result(binding)
      File.open(output_filepath, 'w') do |writer|
        writer.syswrite(content)
      end
    end

    def process_and_copy_up(migration_in_path, migration_out_path, relative_path, loaded_manifest_hash, loaded_manifest)

      if FileTest.directory?(migration_in_path)
        # copy over directories
        # find relative-to-migrations dir this path
        FileUtils.mkdir(migration_out_path)
      else
        if migration_in_path.end_with?('.sql')
          # if a .sql file, then copy & process

          # create the the 'key' version of this name, which is basically the filepath
          # of the .sql file relative without the leading '/' directory
          manifest_name = relative_path[1..-1]

          @log.debug("retrieving manifest definition for #{manifest_name}")

          migration_def = loaded_manifest_hash[manifest_name]

          create_wrapped_up_migration(migration_in_path, migration_out_path, migration_def, loaded_manifest)
        else
          @log.debug "copying non-sql file #{migration_in_path}"
          # if not a .sql file, just copy it over
          FileUtils.cp(migration_in_path, migration_out_path)
        end
      end
    end

    def recreate_test_database(conn, test_db_name)
        @log.debug "recreate test database #{test_db_name}"

        conn.exec("drop database if exists #{test_db_name}")
        conn.exec("create database #{test_db_name}")
      end

      def test(output_dir, test_options)

        @log.info "testing..."
        
        oobconn = Util::get_oob_conn(test_options)
        target_dbname = Util::get_db_name(test_options)

        run_manifests = []


        recreate_test_database(oobconn, target_dbname)

        conn = Util::get_conn(test_options)

        migrator = Migrator.new(manifest_reader, sql_reader, :pgconn => conn)
        migrator.migrate(output_dir)
        conn.close

        @log.info "test success"

      end
  end
end