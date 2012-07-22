module PgMigrate
  class Migration
    attr_accessor :name, :ordinal, :created, :production, :filepath

    def initialize(name, ordinal, filepath)
      @name = name
      @ordinal = ordinal
      @filepath = filepath
    end
    
  end
end