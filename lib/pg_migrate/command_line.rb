module PgMigrate
  class CommandLine < Thor

    desc "up", "migrates the database forwards, applying migrations found in the source directory"
    method_option :source, :aliases => "-s", :default => '.', :lazy_default => '.', :banner => 'input directory', :desc => "a pg_migrate built manifest. Should contain your processed manifest and up|down|test folders"
    method_option :connopts, :aliases => "-o", :type => :hash, :required => true, :banner => "connection options", :desc => "database connection options used by gem 'pg': dbname|host|hostaddr|port|user|password|connection_timeout|options|sslmode|krbsrvname|gsslib|service"
    method_option :verbose, :aliases => "-v", :type => :boolean, :default => false, :banner => "verbose", :desc=> "set to raise verbosity"

    def up
      bootstrap_logger(options[:verbose])

      manifest_reader = ManifestReader.new
      sql_reader = SqlReader.new

      connopts = options[:connopts]
      if !connopts[:port].nil?
        connopts[:port] = connopts[:port].to_i
      end

      migrator = Migrator.new(manifest_reader, sql_reader, connopts)

      begin
        migrator.migrate(options[:source])
      rescue Exception => e
        if !options[:verbose]
          # catch common exceptions and make pretty on command-line
          if !e.message.index("ManifestReader: code=unloadable_manifest").nil?
            puts "Unable to load manifest in source directory '#{options[:source]}' .  Check -s|--source option and run again."
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
      bootstrap_logger(options[:verbose])

      raise 'Not implemented'
    end

    desc "build", "processes a pg_migrate source directory and places the result in the specified output directory"
    method_option :source, :aliases => "-s", :default => '.', :lazy_default => '.', :banner => 'input directory', :desc => "the input directory containing a manifest file and up|down|test folders"
    method_option :out, :aliases => "-o", :required => true, :banner => "output directory", :desc => "where the processed migrations will be placed"
    method_option :force, :aliases => "-f", :default => false, :type => :boolean, :banner => "overwrite out", :desc => "if specified, the out directory will be created before processing occurs, replacing any existing directory"
    method_option :verbose, :aliases => "-v", :type => :boolean, :default => false, :banner => "verbose", :desc=> "set to raise verbosity"

    def build

      bootstrap_logger(options[:verbose])

      manifest_reader = ManifestReader.new
      sql_reader = SqlReader.new
      builder = Builder.new(manifest_reader, sql_reader)
      builder.build(options[:source], options[:out], :force => options[:force])
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
    end
  end
end