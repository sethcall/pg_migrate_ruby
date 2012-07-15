require 'spec_helper'

describe Migrator do

  before(:all) do
    @manifest_reader = ManifestReader.new
    @sql_reader = SqlReader.new
    @standard_migrator = Migrator.new(@manifest_reader, @sql_reader)
  end



end