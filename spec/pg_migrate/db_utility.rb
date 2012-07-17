module PgMigrate

  class DbUtility

    DEFAULT_OPTIONS = {
            :dbtestname => "pg_migrate_test",
            :dbsuperuser => "postgres",
            :dbsuperpass => "postgres",
            :dbhost => "localhost",
            :dbport => 5432
    }

    def initialize(options=DEFAULT_OPTIONS)

      options = DEFAULT_OPTIONS.merge(options)

      @dbtestname = options[:dbtestname]
      @dbsuperuser = options[:dbsuperuser]
      @dbsuperpass = options[:dbsuperpass]
      @dbhost = options[:dbhost]
      @dbport = options[:dbport]
    end

    def pg_connection_hasher()
      return {
              :port => @dbport,
              :user => @dbsuperuser,
              :password => @dbsuperpass,
              :host => @dbhost
      }
    end


    def create_new_test_database()

      # this will presumably do the right default thing,
      # to get us into a 'default' database where we can execute 'create database' from
      conn_properties = pg_connection_hasher

      conn_properties.delete(:dbname)

      conn = PG::Connection.new(conn_properties)

      conn.exec("DROP DATABASE IF EXISTS #{@dbtestname}").clear
      conn.exec("CREATE DATABASE #{@dbtestname}").clear

      conn.close

    end

    def connect_test_database(&block)
      conn = nil

      begin
        conn_properties = pg_connection_hasher

        conn_properties[:dbname] = @dbtestname
        conn = PG::Connection.open(conn_properties)

        yield conn

      ensure
        if !conn.nil?
          conn.close
        end
      end


    end

  end

end
