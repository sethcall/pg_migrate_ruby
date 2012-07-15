module PgMigrate

  class SqlReader

    def initialize

    end


    # read in a migration file,
    # converting lines of text into SQL statements that can be executed with our database connection
    def load_migration(migration_path)
      statements = []

      current_statement = ""

      migration_lines = IO.readlines(migration_path)
      migration_lines.each_with_index do |line, index|
        line_stripped = line.strip

        if line_stripped.empty? || line_stripped.start_with?('--')
          # it's a comment; ignore
        elsif line_stripped.start_with?("\\")
          # it's a psql command; ignore
        else
          current_statement += " " + line_stripped;

          if line_stripped.end_with?(";")
            if current_statement =~ /^\s*CREATE\s+(OR\s+REPLACE\s+)?FUNCTION/i
              # if we are in a function, a ';' isn't enough to end.  We need to see if the last word was one of
              # pltcl, plperl, plpgsql, plpythonu, sql.
              # you can extend languages in postgresql; detecting these isn't supported yet.

              if current_statement =~ /(plpgsql|plperl|plpythonu|pltcl|sql)\s*;$/i
                statements.push(current_statement[0...-1]) # strip off last ;
                current_statement = ""
              end

            else
              statements.push(current_statement[0...-1]) # strip off last ;
              current_statement = ""
            end
          end
        end
      end

      return statements

    end
  end
end