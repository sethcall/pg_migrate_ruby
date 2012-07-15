require 'spec_helper'

describe SqlReader do

  before(:all) do
    @sql_reader = SqlReader.new
  end

  it "load single migration" do
    migrations = @sql_reader.load_migration("spec/pg_migrate/input_manifests/single_manifest/up/single1.sql")

    migrations.length.should == 7
    migrations[0] = "select 1"
    migrations[1] = "select 2"
    migrations[2] = "select 3"
    migrations[3] = "create table emp()"
    migrations[4] = "CREATE FUNCTION clean_emp() RETURNS void AS ' DELETE FROM emp; ' LANGUAGE SQL"
    migrations[5] = "CREATE FUNCTION clean_emp2() RETURNS void AS 'DELETE FROM emp;' LANGUAGE SQL"
    migrations[6] = "CREATE FUNCTION populate() RETURNS integer AS $$ DECLARE BEGIN PERFORM select 1; END; $$ LANGUAGE plpgsql"
  end

end