require 'spec_helper'

describe Migrator do

  before(:all) do
    @manifest_reader = ManifestReader.new
    @sql_reader = SqlReader.new
    @standard_builder = Builder.new(@manifest_reader, @sql_reader)
    @standard_migrator = Migrator.new(@manifest_reader, @sql_reader)
    @dbutil = DbUtility.new
  end

  it "migrate single_manifest" do

    def migrate_it(output_dir)
      @dbutil.connect_test_database do |conn|

        standard_migrator = Migrator.new(@manifest_reader, @sql_reader, :pgconn=>conn)
        standard_migrator.migrate(output_dir)

        conn.transaction do |transaction|
          transaction.exec("SELECT table_name FROM information_schema.tables WHERE table_name = $1", ["emp"]) do |result|
            result.ntuples.should == 1
            result.getvalue(0, 0).should == "emp"
          end

          pg_migration_id = nil
          transaction.exec("SELECT * FROM pgmigrate.pg_migrations") do |result|
            result.ntuples.should == 1
            result[0]["name"].should == "single1.sql"
            result[0]["ordinal"].should == "0"
            pg_migration_id = result[0]["pg_migrate_id"]
          end
          pg_migration_id.should_not == nil

          # verify that a database row in pg_migrate was created as side-effect
          transaction.exec("SELECT * FROM pgmigrate.pg_migrate WHERE id = $1", [pg_migration_id]) do |result|
            result.ntuples.should == 1
            result[0]["template_version"].should == "0.1.0"
            result[0]["builder_version"].should == "pg_migrate_ruby-#{PgMigrate::VERSION}"
            result[0]["migrator_version"].should == "pg_migrate_ruby-#{PgMigrate::VERSION}"
            result[0]["database_version"].should_not be nil
          end
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

    @standard_builder.build(input_dir, output_dir, :force => true)

    @dbutil.create_new_test_database

    migrate_it(output_dir)
    migrate_it(output_dir)
  end
end

