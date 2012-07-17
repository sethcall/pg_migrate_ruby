require 'pathname'

module PgMigrate
  class ManifestReader

    def initialize
      @log = Logging.logger[self]
    end

    # returns array of migration paths
    def load_input_manifest(manifest_path)
      manifest, version = load_manifest(manifest_path, false)
      return manifest
    end

    # returns [array of migration paths, version]
    def load_output_manifest(manifest_path)
      return load_manifest(manifest_path, true)
    end


    # verify that the migration files exist
    def validate_migration_paths(manifest_path, manifest)
      # each item in the manifest should be a valid file
      manifest.each do |item|
        item_path = build_migration_path(manifest_path, item.name)
        if !Pathname.new(item_path).exist?
          raise "manifest reference #{item.name} does not exist at path #{item_path}"
        end
      end
    end

    # construct a migration file path location based on the manifest basedir and the name of the migration
    def build_migration_path(manifest_path, migration_name)
      File.join(manifest_path, UP_DIRNAME, "#{migration_name}")
    end

    def hash_loaded_manifest(loaded_manifest)
      hash = {}
      loaded_manifest.each do |manifest|
        hash[manifest.name] = manifest
      end
      return hash
    end

    # read in the manifest, saving each migration declaration in order as they are found
    private
    def load_manifest(manifest_path, is_output)

      manifest = []
      version = nil

      manifest_filepath = File.join(manifest_path, MANIFEST_FILENAME)

      @log.debug "loading manifest from #{manifest_path}"

      if !FileTest::exist?(manifest_filepath)
        raise "unable to load manifest: not found at #{manifest_path}"
      end

      # there should be a file called 'manifest' at this location
      manifest_lines = IO.readlines(manifest_filepath)

      ordinal = 0
      manifest_lines.each_with_index do |line, index|
        # ignore comments
        migration_name = line.strip

        @log.debug "processing line:#{index} #{line}"

        # output files must have a version header as 1st line o file
        if is_output
          if index == 0
            # the first line must be the version comment. if not, error out.
            if migration_name.index(BUILDER_VERSION_HEADER) == 0 && migration_name.length > BUILDER_VERSION_HEADER.length
              version = migration_name[BUILDER_VERSION_HEADER.length..-1]
              @log.debug "manifest has builder_version #{version}"
            else
              raise "manifest invalid: missing/malformed version.  expecting '# pg_migrate-VERSION' to begin first line '#{line}' of manifest file: '#{manifest_path}'"
            end
          end
        end

        if migration_name.empty? or migration_name.start_with?('#')
          # ignored!
        else
          @log.debug "adding manifest #{migration_name} with ordinal #{ordinal}"
          manifest.push(Migration.new(migration_name, ordinal, build_migration_path(manifest_path, migration_name)))
          ordinal += 1
        end

        # the logic above wouldn't get upset with an empty manifest
        if is_output
          if version.nil?
            raise "manifest invalid: empty"
          end
        end
      end
      return manifest, version
    end

  end
end