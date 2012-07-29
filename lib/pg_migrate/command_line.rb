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

    def build
      source = options[:source]

      if source.nil?
        source = @@packaged_source
      end

      method_defaults = {"force" => false, "verbose" => false}
      local_options = set_defaults_from_file(method_defaults, "build", source)
      local_options = local_options.merge(options)

      bootstrap_logger(local_options["verbose"])

      if !local_options["out"]
        puts "error: --out not specified"
        exit 1
      end

      manifest_reader = ManifestReader.new
      sql_reader = SqlReader.new
      builder = Builder.new(manifest_reader, sql_reader)
      builder.build(source, local_options["out"], :force => local_options["force"])
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
    end


  end
end