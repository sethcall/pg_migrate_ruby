module PgMigrate

  class Util

    LOGGER = Logging.logger[self]

    # recommended to create all connections via this method,
    # so that we can put NOTICE/CONTEXT into logger instead of stderr
    def self.create_conn(args)
      conn = PG::Connection.open(args)
      conn.set_notice_receiver do |result|
          #result.res_status(result.result_status)
          LOGGER.debug result.error_message
      end
      return conn
    end

    def self.get_conn(connection_options)
      if !connection_options[:pgconn].nil?
        return connection_options[:pgconn]
      elsif !connection_options[:connstring].nil?
        create_conn(connection_options[:connstring])
      elsif !connection_options[:connopts].nil?
        return create_conn(connection_options[:connopts])
      else
        return create_conn(connection_options)
      end
    end

    # the 'out-of-band' conn is a connection to a database that you aren't
    # interested in modifying; it's basically a landing pad so that you can do:
    # DROP DATABSE BLAH; CREATE DATABASE BLAH -- for testing
    def self.get_oob_conn(connection_options)

      if !connection_options[:oob_pgconn].nil?
        return connection_options[:oob_pgconn]
      elsif !connection_options[:oob_connstring].nil?
        return create_conn(connection_options[:oob_connstring])
      elsif !connection_options[:oob_connopts].nil?
        return create_conn(connection_options[:oob_connopts])
      else
        return create_conn(connection_options)
      end
    end

    # finds dbname from connection_options
    def self.get_db_name(connection_options)
      dbname = nil
      if !connection_options[:pgconn].nil?
        dbname = connection_options[:pgconn].db
      elsif !connection_options[:connstring].nil?
        connstring = connection_options[:connstring]
        bits = connstring.split(" ")
        bits.each do |bit|
          if bit.start_with? "dbname="
            dbname = bit["dbname=".length..-1]
            break
          end
        end
      elsif !connection_options[:connopts].nil?
        dbname = connection_options[:connopts]["dbname"]
      else
        dbname = connection_options["dbname"]
      end

      if dbname.nil?
        raise "db name is null.  tried finding dbname in #{connection_options.inspect}"
      end

      return dbname
    end
  end
end
