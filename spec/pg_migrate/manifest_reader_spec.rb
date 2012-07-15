require 'spec_helper'

describe ManifestReader do

  before(:all) do
    @manifest_reader = ManifestReader.new
  end

  it "load single manifest" do
    manifest = @manifest_reader.load_manifest("spec/pg_migrate/input_manifests/single_manifest")

    manifest.length.should == 1
    manifest[0].name.should == "single1.sql"
  end

  it "fail on bad manifest reference" do
    expect { @manifest_reader.validate_migration_paths('absolutely_nowhere_real', ["migration1"]) }.to raise_exception
  end

end