require 'spec_helper'

describe Package do

  before(:all) do
    @manifest_reader = ManifestReader.new
    @sql_reader = SqlReader.new
    @builder = Builder.new(@manifest_reader, @sql_reader)
    @packager = Package.new(@manifest_reader)
    @dbutil = DbUtility.new
  end

  it "package single migration project" do
    single_manifest=File.expand_path('spec/pg_migrate/input_manifests/single_manifest')
    single_manifest = File.join(single_manifest, '.')

    input_dir = nil
    target = Files.create :path => "target", :timestamp => false do
      input_dir = dir "input_single_manifest", :src => single_manifest do

      end
    end

    build_output_dir = File.join('target', 'output_single_manifest')
    package_output_dir = File.join('target', 'package_single_manifest')

    FileUtils.rm_rf(build_output_dir)


    # build first
    @builder.build(input_dir, build_output_dir)

    # then attempt a package
    @packager.package(build_output_dir, package_output_dir, "crazy_gem", "0.0.1")

  end

end
