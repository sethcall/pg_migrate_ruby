require 'spec_helper'

describe Builder do

  before(:all) do
    @manifest_reader = ManifestReader.new
    @sql_reader = SqlReader.new
    @standard_builder = Builder.new(@manifest_reader, @sql_reader)
    @dbutil = DbUtility.new
  end

  it "create bootstrap.sql" do
    standard_builder = @standard_builder
    target = Files.create :path => "target/bootstrap_test", :timestamp => false do
      standard_builder.create_bootstrap_script(Dir.pwd)

      # the .sql file should exist after
      FileTest::exists?(BOOTSTRAP_FILENAME).should == true

      content = nil

      # dynamic content should be in the file
      File.open(BOOTSTRAP_FILENAME, 'r') { |reader| content = reader.read }

      content.start_with?('-- pg_migrate bootstrap').should == true
    end

  end

  it "creates indempotent migrations" do

    def run_bootstrap(output_dir)
      run_migration(BOOTSTRAP_FILENAME, output_dir)
    end

    def run_migration(migration_path, output_dir)
      @dbutil.connect_test_database() do |conn|
        statements = @sql_reader.load_migration(File.join(output_dir, UP_DIRNAME, migration_path))

        statements.each do |statement|
          conn.exec(statement)
        end
      end
    end

    def verify_bootstrap()
      # come back in, and verify that the bootstrap tables are there
      @dbutil.connect_test_database() do |conn|
        conn.exec("SELECT table_name FROM information_schema.tables WHERE table_name = $1", [PG_MIGRATE_TABLE]) do |result|
          result.ntuples.should == 1
          result.getvalue(0, 0).should == PG_MIGRATE_TABLE
        end

        conn.exec("SELECT table_name FROM information_schema.tables WHERE table_name = $1", [PG_MIGRATIONS_TABLE]) do |result|
          result.ntuples.should == 1
          result.getvalue(0, 0).should == PG_MIGRATIONS_TABLE
        end

      end
    end

    single_manifest=File.expand_path('spec/pg_migrate/input_manifests/single_manifest')
    single_manifest = File.join(single_manifest, '.')

    input_dir = nil
    target = Files.create :path => "target", :timestamp => false do
      input_dir = dir "input_single_manifest", :src => single_manifest do

      end
    end

    output_dir = File.join('target', 'output_single_manifest')

    FileUtils.rm_rf(output_dir)

    @standard_builder.build(input_dir, output_dir)

    @dbutil.create_new_test_database()

    # run bootstrap once, and verify the tables now exist
    run_bootstrap(output_dir)
    verify_bootstrap()

    # run bootstrap again, and verify no error (implicitly), and that the tables now exist
    run_bootstrap(output_dir)
    verify_bootstrap()

    # now run single1.sql
    run_migration('single1.sql', output_dir)

    @dbutil.connect_test_database() do |conn|
      conn.exec("SELECT table_name FROM information_schema.tables WHERE table_name = $1", ["emp"]) do |result|
        result.ntuples.should == 1
        result.getvalue(0, 0).should == "emp"
      end
    end

    # run it again.  a very certain exception should occur... 'pg_migrate: code=migration_exists'
    begin
      run_migration('single1.sql', output_dir)
      false.should == true
    rescue Exception => e
      e.message.index('pg_migrate: code=migration_exists').should_not == nil
    end

    @dbutil.connect_test_database() do |conn|
      conn.exec("SELECT table_name FROM information_schema.tables WHERE table_name = $1", ["emp"]) do |result|
        result.ntuples.should == 1
        result.getvalue(0, 0).should == "emp"
      end
    end

  end
end