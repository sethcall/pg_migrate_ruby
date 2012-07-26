# from comment at http://devender.wordpress.com/2006/05/01/reading-and-writing-java-property-files-with-ruby/

module PgMigrate
  class Properties < Hash
    def initialize(filename = nil)
      if (filename) then
        File.open(filename).select { |line| not line=~/^[ \t]*(#.+)*$/ }.# ignore comments and blank lines
        each { |line|
          (k, v) = line.chomp.split('=', 2)
          self[k.strip] = v.strip
        }
      end
    end

    def to_s
      self.map { |k, v| " #{k}=#{v}" }.join("\n")
    end
  end
end
