require 'pathname'

module PgMigrate
  class ManifestReader

    def initialize
      @log = Logging.logger[self]
    end

    # read in the manifest, saving each migration declaration in order as they are found
    def load_manifest(manifest_path)

      manifest = []
      manifest_filepath = File.join(manifest_path, MANIFEST_FILENAME)

      @log.debug("loading manifest from #{manifest_path}")
          
      # there should be a file called 'manifest' at this location
      manifest_lines = IO.readlines(manifest_filepath)
      manifest_lines.each_with_index do |line, index|
        # ignore comments
        migration_name = line.strip
        if migration_name.empty? or migration_name.start_with?('#')
          # ignored!
        else
          manifest.push(Migration.new(migration_name, index, build_migration_path(manifest_path, migration_name)))
        end
      end

      return manifest
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

  end
end