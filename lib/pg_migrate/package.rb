require 'erb'
require 'fileutils'
require 'rubygems'

begin 
    # this occurs in rubygems < 2.0.0
    require 'rubygems/builder'
rescue LoadError
    # this occurs in rubygems > 2.0.0
    require 'rubygems/package'
end

module PgMigrate
  class Package

    attr_accessor :manifest_reader

    def initialize(manifest_reader)
      @log = Logging.logger[self]
      @manifest_reader = manifest_reader
      @template_dir = File.join(File.dirname(__FILE__), 'package_templates')
    end

    def package(built_migration_path, output_dir, name, version, options={:force=>true})
      gemspec = create_gem(built_migration_path, output_dir, name, version, options[:force])
      build_gem(gemspec, output_dir)
    end

    def create_gem (built_migration_path, output_dir, name, version, force)
      # validate that manifest is valid
      @log.debug "validating output dir is manifest"

      if !FileTest::exist?(built_migration_path)
        raise "built manifest path does not exist #{built_migration_path}"
      end

      if built_migration_path == output_dir
        raise "source and destination can not be the same path"
      end

      loaded_manifest = @manifest_reader.load_input_manifest(built_migration_path)
      @manifest_reader.validate_migration_paths(built_migration_path, loaded_manifest)

      @log.debug "preparing to build gem"

      target = File.join(output_dir, name)

      # stolen almost verbatim from bundler: https://github.com/carlhuda/bundler/blob/master/lib/bundler/cli.rb
      constant_name = name.split('_').map { |p| p[0..0].upcase + p[1..-1] }.join
      constant_name = constant_name.split('-').map { |q| q[0..0].upcase + q[1..-1] }.join('::') if constant_name =~ /-/
      constant_array = constant_name.split('::')
      # end stolen

      author = "pgmigrate"
      email = "pgmigrate@pgmigrate.io"
      pg_migrate_version = PgMigrate::VERSION
      gemfiles = ["Gemfile", "#{name}.gemspec", "lib/#{name}.rb", "lib/#{name}/version.rb", "bin/#{name}"]
      gemfiles += userfiles(built_migration_path, name)
      gemspec_path = File.join(output_dir, "#{name}.gemspec")

      @log.debug "building gem"

      output = Pathname.new(output_dir)
      if !output.exist?
        if !force
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

      FileUtils.mkdir_p(output_dir)
      FileUtils.mkdir_p(File.join(output_dir, "bin"))
      FileUtils.mkdir_p(File.join(output_dir, "lib", name))
      run_template("Gemfile.erb", binding, File.join(output_dir, "Gemfile"))
      run_template("gemspec.erb", binding, gemspec_path)
      run_template("lib/gem.rb", binding, File.join(output_dir, "lib", "#{name}.rb"))
      run_template("lib/gem/version.rb", binding, File.join(output_dir, "lib", name, "version.rb"))
      run_template("bin/migrate.rb", binding, File.join(output_dir, "bin", "#{name}"))
      copy_schema(built_migration_path, File.join(output_dir, "lib", name, "schemas"))

      return gemspec_path
    end

    def copy_schema(built_migration_path, output_dir)
      FileUtils.cp_r(File.join(built_migration_path, '.'), output_dir)
    end
    
    def build_gem(gemspec_path, output_dir)
      @log.debug "building gem"

      @log.debug "loading gem specification #{gemspec_path}"
      spec = Gem::Specification.load(gemspec_path)

      if spec.nil?
        raise 'unable to build gem from specification'
      end
      
      @log.debug "packaging gem"
      Dir.chdir(output_dir) do
        if defined?(Gem::Builder)
          Gem::Builder.new(spec).build
        else
          Gem::Package.build(spec)
        end
      end
      #Gem::Package.build spec, false
    end

    def userfiles(built_migration_path, name)

      gempaths = []
      Find.find(built_migration_path) do |path|
        if path == ".."
          Find.prune
        else
          # make relative

          relative = path[built_migration_path.length..-1]
          gempath = File.join("lib", name, "schemas", relative)
          gempaths.push(gempath)
        end
      end

      return gempaths
    end

    # given an input template and binding, writes to an output file
    def run_template(template, opt, output_filepath)
      bootstrap_template = nil
      File.open(File.join(@template_dir, template), 'r') do |reader|
        bootstrap_template   = reader.read
      end


      template = ERB.new(bootstrap_template, 0, "%<>")
      content = template.result(opt)
      File.open(output_filepath, 'w') do |writer|
        writer.syswrite(content)
      end
    end
  end
end
