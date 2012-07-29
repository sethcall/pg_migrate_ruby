require 'spec_helper'

describe CommandLine do

  before(:all) do
    @dbutil = DbUtility.new
  end


  it "build using config file" do

    single_manifest=File.expand_path('spec/pg_migrate/input_manifests/single_manifest')
    single_manifest=File.join(single_manifest, '.')

    input_dir = nil
    target = Files.create :path => "target", :timestamp => false do
      input_dir = dir "input_single_manifest", :src => single_manifest do

      end
    end

    output_dir = File.join("target", 'output_single_manifest')

    FileUtils.rm_rf(output_dir)

    # make a properties file on the fly, with the out parameter specified
    props = Properties.new
    props['build.out'] = output_dir
    props['build.force'] = "true"
    #props['up.connopts'] = "dbname:pg_migrate_test host:localhost port:5432 user:postgres password:postgres"

    # and put that properties file in the input dir
    File.open(File.join(input_dir, PG_CONFIG), 'w') { |f| f.write(props) }

    # invoke pg_migrate build, with the hopes that the output dir is honored
    result = `bundle exec pg_migrate build -s #{input_dir}`

    puts "pg_migrate build output: #{result}"

    $?.exitstatus.should == 0

    FileTest::exist?(output_dir).should == true
    FileTest::exist?(File.join(output_dir, MANIFEST_FILENAME)).should == true
    FileTest::exist?(File.join(output_dir, PG_CONFIG)).should == true
    FileTest::exist?(File.join(output_dir, UP_DIRNAME)).should == true
    FileTest::exist?(File.join(output_dir, UP_DIRNAME, BOOTSTRAP_FILENAME)).should == true
    FileTest::exist?(File.join(output_dir, UP_DIRNAME, "single1.sql")).should == true


  end


end