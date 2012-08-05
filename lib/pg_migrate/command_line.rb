module PgMigrate
  class CommandLine < Thor

    @@packaged_source = '.'

    def initialize(*args)
      super
    end

    def self.packaged_source
      @@packaged_source
    end

    def self.packaged_source=(value)
      @@packaged_source = value
    end


    desc "up", "migrates the database forwards, applying migrations found in the source directory"
    method_option :source, :aliases => "-s", :default => nil, :banner => 'input directory', :desc => "a pg_migrate built manifest. Should contain your processed manifest and up|down|test folders"
    method_option :connopts, :aliases => "-c", :type => :hash, :required => true, :banner => "connection options", :desc => "database connection options used by gem 'pg': dbname|host|hostaddr|port|user|password|connection_timeout|options|sslmode|krbsrvname|gsslib|service"
    method_option :verbose, :aliases => "-v", :type => :boolean, :banner => "verbose", :desc=> "set to raise verbosity"

    def up
      source = options[:source]

      if source.nil?
        source = @@packaged_source
      end

      method_defaults = {"verbose" => false}
      local_options = set_defaults_from_file(method_defaults, "up", source)
      local_options = local_options.merge(options)

      bootstrap_logger(local_options["verbose"])

      manifest_reader = ManifestReader.new
      sql_reader = SqlReader.new

      connopts = local_options["connopts"]
      if !connopts["port"].nil?
        connopts[:port] = connopts[:port].to_i
      end

      migrator = Migrator.new(manifest_reader, sql_reader, connopts)

      begin
        migrator.migrate(source)
      rescue Exception => e
        if !local_options["verbose"]
          # catch common exceptions and make pretty on command-line
          if !e.message.index("ManifestReader: code=unloadable_manifest").nil?
            puts "Unable to load manifest in source directory '#{source}' .  Check -s|--source option and run again."
            exit 1
          else
            raise e
          end
        else
          raise e
        end
      end


    end

    desc "down", "not implemented"

    def down
      local_options = options
      options = set_defaults_from_file(location_options)
      bootstrap_logger(options[:verbose])

      raise 'Not implemented'
    end

    desc "build", "processes a pg_migrate source directory and places the result in the specified output directory"
    method_option :source, :aliases => "-s", :default => nil, :banner => 'input directory', :desc => "the input directory containing a manifest file and up|down|test folders"
    method_option :out, :aliases => "-o", :banner => "output directory", :desc => "where the processed migrations will be placed"
    method_option :force, :aliases => "-f", :type => :boolean, :banner => "overwrite out", :desc => "if specified, the out directory will be created before processing occurs, replacing any existing directory"
    method_option :verbose, :aliases => "-v", :type => :boolean, :banner => "verbose", :desc=> "set to raise verbosity"
    method_option :test, :aliases => "-t", :default => false, :type => :boolean, :banner => "run tests", :desc => "run tests by creating a test database and executing migrations"
    method_option :oob_connopts, :aliases => "-b",:default=> nil,  :type => :hash, :banner => "out-of-band connection options", :desc => "this is a 'landing pad' database from which pg_migrate can execute 'create/drop' against the database specified by the connopts argument. database connection options used by gem 'pg': dbname|host|hostaddr|port|user|password|connection_timeout|options|sslmode|krbsrvname|gsslib|service"
    method_option :connopts, :aliases => "-c", :default => nil, :type => :hash, :banner => "connection options", :desc => "database connection options used by gem 'pg': dbname|host|hostaddr|port|user|password|connection_timeout|options|sslmode|krbsrvname|gsslib|service"

    def build
      source = options[:source]

      if source.nil?
        source = @@packaged_source
      end

      method_defaults = {"force" => false, "verbose" => false, "test" => false}
      local_options = set_defaults_from_file(method_defaults, "build", source)
      local_options = local_options.merge(options)

      bootstrap_logger(local_options["verbose"])

      if !local_options["out"]
        puts "error: --out not specified"
        exit 1
      end

      if local_options["test"].to_s == "true"
        if !local_options["oob_connopts"]
          puts "error: --oob_connopts not specified when test = true"
          exit 1
        else
          # type safety; if string is found, convert to hash
          local_options["oob_connopts"] = parse_to_hash(local_options["oob_connopts"])
        end


        if !local_options["connopts"]
          puts "error: --connopts not specified when test = true"
          exit 1
        else
          # type safety; if string is found, convert to hash
          local_options["connopts"] = parse_to_hash(local_options["connopts"])
        end

      end

      manifest_reader = ManifestReader.new
      sql_reader = SqlReader.new
      builder = Builder.new(manifest_reader, sql_reader)

      begin
      builder.build(source, local_options["out"],
                    :force => local_options["force"],
                    :test => local_options["test"],
                    :oob_connopts => local_options["oob_connopts"],
                    :connopts => local_options["connopts"])
      rescue PG::Error => pge
        puts "test failure"
        puts pge
      end

    end


    desc "package", "packages a built pg_migrate project into a custom gem containing schemas and simpler migration interface"
    method_option :source, :aliases => "-s", :default => nil, :banner => 'input directory', :desc => "the input directory containing a manifest file and up|down|test folders that has been previously built by pg_migrate build"
    method_option :out, :aliases => "-o", :banner => "output directory", :desc => "where the gem will be placed (as well as the exploded gem's contents)"
    method_option :name, :aliases => "-n", :banner => "the name of the schema gem", :desc => "the name of the gem"
    method_option :version, :aliases => "-e", :banner => "the version of the schema gem", :desc => "the version of the gem"
    method_option :force, :aliases => "-f", :type => :boolean, :banner => "overwrite out", :desc => "if specified, the out directory will be created before processing occurs, replacing any existing directory"
    method_option :verbose, :aliases => "-v", :type => :boolean, :banner => "verbose", :desc=> "set to raise verbosity"

    def package
      source = options[:source]

      if source.nil?
        source = @@packaged_source
      end

      method_defaults = {"force" => false, "verbose" => false}
      local_options = set_defaults_from_file(method_defaults, "package", source)
      local_options = local_options.merge(options)

      if !local_options["out"]
        puts "error: --out not specified"
        exit 1
      end
      if !local_options["name"]
        puts "error: --version not specified"
        exit 1
      end
      if !local_options["version"]
        puts "error: --version not specified"   
        exit 1
      end

      bootstrap_logger(local_options["verbose"])

      manifest_reader = ManifestReader.new
      builder = Package.new(manifest_reader)
      builder.package(source, local_options["out"], local_options["name"], local_options["version"], :force => local_options["force"])
    end

    no_tasks do
      def bootstrap_logger(verbose)
        # bootstrap logger
        if verbose
          Logging.logger.root.level = :debug
        else
          Logging.logger.root.level = :info
        end

        Logging.logger.root.appenders = Logging.appenders.stdout
      end


      def set_defaults_from_file(default_options, context, source)
        @file_defaults = @file_defaults ||= load_file(context, source)
        merged = default_options.merge(@file_defaults)
      end

      def load_file(context, source)

        defaults = nil
        config = File.join(source, PG_CONFIG)
        if FileTest::exist? (config)
          puts "found #{PG_CONFIG}"
          defaults = Properties.new(config)
        else
          defaults = Properties.new
        end

        map = {}
        defaults.each_pair do |k, v|
          map[k.upcase] = v

          # make a context-removed version of a key, if it starts with 'context.'
          prefix = "#{context}."
          if k.start_with? prefix
            map[k[prefix.length..-1]] = v
          end
        end

        return map

      end

      def parse_to_hash(value)
        hash = {}

        bits = value.split()
        bits.each do |bit|
          key, value = bit.split(':',2)
          hash[key] = value
        end

        return hash
      end
    end


  end
end