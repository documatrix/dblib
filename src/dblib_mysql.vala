/*
 * This file contains the MySQL driver of the DBLib.
 * (c) 2014 by DocuMatrix GmbH
 */

namespace DBLib
{
  namespace MySQL
  {
    public class Connection : DBLib.Connection
    {
      /**
       * The MySQL database handle.
       */
      public Mysql.Database dbh;

      /**
       * This constructor will create a new database connection to a MySQL database.
       * @param dsn A DataSourceName object containing the informations which will be passed to the MySQL library.
       * @param user A user which should be used to connect to the database.
       * @param password A password which should be used to connect to the database.
       * @throws DBLib.DBError if an error occurs while connecting to the MySQL database.
       */
      public Connection( DataSourceName dsn, string? user, string? password ) throws DBLib.DBError.CONNECTION_ERROR
      {
        this.dsn = dsn;

        this.dbh = new Mysql.Database( );

        uint port = 0;
        if ( dsn[ "port" ] != null )
        {
          port = (uint)uint64.parse( dsn[ "port" ] );
        }
        if ( !this.dbh.real_connect( dsn[ "host" ], user, password, dsn[ "database" ], port, dsn[ "unix_socket" ] ) )
        {
          throw new DBLib.DBError.CONNECTION_ERROR( "Could not connect to MySQL database! %u: %s", this.dbh.errno( ), this.dbh.error( ) );
        }
      }

      /**
       * @see DBLib.Connection.escape
       */
      public override string escape( string? val )
      {
        if ( val == null )
        {
          return "NULL";
        }
        else
        {
          string escaped = string.nfill( val.length * 2 + 1, ' ' );
          ulong res_len = this.dbh.real_escape_string( escaped, val, val.length );
          return "\"" + escaped + "\"";
        }
      }

      /**
       * @see DBLib.Connection.execute_query
       */
      public override void execute_query( string code ) throws DBLib.DBError.STATEMENT_ERROR
      {
        if ( this.dbh.real_query( code, code.length ) != 0 )
        {
          throw new DBLib.DBError.STATEMENT_ERROR( "Could not execute query \"%s\" on MySQL database! %u: %s", code, this.dbh.errno( ), this.dbh.error( ) );
        }
      }

      /**
       * @see DBLib.Connection.get_result
       */
      public override DBLib.Result get_result( bool server_side_result ) throws DBLib.DBError.RESULT_ERROR
      {
        return new DBLib.MySQL.Result( this, server_side_result );
      }

      /**
       * @see DBLib.Connection.get_insert_id
       */
      public override uint64 get_insert_id( )
      {
        return this.dbh.insert_id( );
      }
    }

    /**
     * This class is a implementation for the abstract class DBLib.Result
     */
    public class Result : DBLib.Result
    {
      /**
       * The MySQL connection which is used to fetch the result.
       */
      private DBLib.MySQL.Connection mysql_conn;

      /**
       * The result object which was fetched from MySQL.
       */
      private Mysql.Result? mysql_result;

      /**
       * This array may contain the field informations for the resultset.
       * It will be initialized by fetchrow_hash the first time the method is called.
       */
      private Mysql.Field[] mysql_fields;

      /**
       * @see DBLib.Result
       * @throws DBLib.DBError.RESULT_ERROR if an error occurs while fetching the result from MySQL.
       */
      public Result( DBLib.MySQL.Connection conn, bool server_side_result ) throws DBLib.DBError.RESULT_ERROR
      {
        base( conn, server_side_result );

        this.mysql_conn = (DBLib.MySQL.Connection)conn;

        this.mysql_result = null;
        if ( this.server_side_result )
        {
          this.mysql_result = this.mysql_conn.dbh.use_result( );
        }
        else
        {
          this.mysql_result = this.mysql_conn.dbh.store_result( );
        }

        /*
         * When the acquired result is null there was maybe an error...
         */
        if ( this.mysql_result == null && this.mysql_conn.dbh.errno( ) != 0 )
        {
          throw new DBLib.DBError.RESULT_ERROR( "Error while fetching result from database server! %u: %s", this.mysql_conn.dbh.errno( ), this.mysql_conn.dbh.error( ) );
        }
      }

      /*
       * @see DBLib.Result.fetchrow_hash
       */
      public override HashTable<string?,string?>? fetchrow_hash( )
      {
        string[]? row_data = this.mysql_result.fetch_row( );
        if ( row_data == null )
        {
          return null;
        }

        if ( this.mysql_fields == null )
        {
          this.mysql_fields = this.mysql_result.fetch_fields( );
        }

        HashTable<string?,string?> row = new HashTable<string?,string?>( str_hash, str_equal );
        for ( int i = 0; i < this.mysql_fields.length; i ++ )
        {
          row.insert( this.mysql_fields[ i ].name, row_data[ i ] );
        }
        return row;
      }

      /**
       * @see DBLib.Result.fetchrow_array
       */
      public override string[]? fetchrow_array( )
      {
        return this.mysql_result.fetch_row( );
      }


      /**
       * @see DBLib.Result.fetchrow_binary
       */
      public override char** fetchrow_binary( out ulong[] array_length )
      {
        char** data = this.mysql_result.fetch_row( );
        if ( data == null )
        {
          return null;
        }
        array_length = this.mysql_result.fetch_lengths( );
        return data;
      }
    }
  }
}
