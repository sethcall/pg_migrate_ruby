require 'spec_helper'

describe ConfigParser do
  it "parse my test database.yml file" do
    config = ConfigParser.rails("spec/database.yml", "test")
    config.should == {
            :dbname => "pg_migrate_test",
            :user => "postgres",
            :password => "postgres",
            :host => "localhost",
            :port => 5432
    }
  end
  
  it "run single migration" do
    config = ConfigParser.rails("spec/database.yml", "test")
  end

end