#!/usr/bin/env ruby

require 'pg_migrate'
require '<%= name %>'

include PgMigrate

CommandLine.packaged_source = File.expand_path('../../lib/<%= name %>/schemas', __FILE__)

CommandLine.start